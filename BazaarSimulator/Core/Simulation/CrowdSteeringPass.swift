import Foundation
import simd

nonisolated struct CrowdNeighbor {
    let offset: SIMD2<Double>
    let velocity: SIMD2<Double>
    let combinedRadius: Double
    let weight: Double
}

private nonisolated struct CrowdDesire {
    var direction = SIMD2<Double>.zero
    var speed = 0.0
}

/// Computes one agent's next velocity from read-only copies of the step's state.
nonisolated struct CrowdSteeringPass {
    static let maxNeighbors = 48
    private static let headingOffsets = [0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4]
    private static let speedFractions = [1.0, 0.5]
    private static let neighborRadiusSquared = 6.25

    let bodies: UnsafeBufferPointer<CrowdBody>
    let motions: UnsafeBufferPointer<CrowdPartyMotion>
    let hash: CrowdSpatialHash
    let walls: CrowdWallMap

    func velocity(ofBodyAt index: Int, neighbors: inout [CrowdNeighbor]) -> SIMD2<Double> {
        let body = bodies[index]
        let motion = motions[body.partyIndex]
        let density = localDensity(aroundBodyAt: index)

        var desire = body.isLeader
            ? CrowdDesire(direction: body.routeDirection, speed: motion.leaderWalkSpeed)
            : followerDesire(body, motion: motion, density: density)
        desire.speed *= CrowdSimulation.crowdFactor(density: density)
        guard desire.speed >= 0.02 else { return .zero }

        collectNeighbors(ofBodyAt: index, into: &neighbors)
        let steered = steer(body, desire: desire, neighbors: neighbors)
        var velocity = body.velocity + (steered - body.velocity) * min(1, CrowdParameters.stepSeconds / 0.35)
        let speedCap = motion.speed * 1.35
        if simd_length(velocity) > speedCap { velocity = simd_normalize(velocity) * speedCap }
        return velocity
    }

    /// People per square metre around one person. Seated people do not count.
    private func localDensity(aroundBodyAt index: Int) -> Double {
        let radiusSquared = CrowdParameters.densityRadius * CrowdParameters.densityRadius
        let position = bodies[index].position
        var people = bodies[index].weight
        hash.forEachNearby(position) { other in
            guard other != index, !bodies[other].isSeated else { return }
            if simd_distance_squared(bodies[other].position, position) < radiusSquared {
                people += bodies[other].weight
            }
        }
        return people / (Double.pi * radiusSquared)
    }

    /// A follower heads for its slot beside the leader, or takes the legal route when a wall is between them.
    private func followerDesire(_ body: CrowdBody, motion: CrowdPartyMotion, density: Double) -> CrowdDesire {
        let leader = bodies[motion.leaderIndex]
        let leaderSpeed = simd_length(leader.velocity)
        let isIdle = motion.isStill || leaderSpeed < 0.15

        guard walls.hasLineOfSight(from: body.position, to: leader.position) else {
            return CrowdDesire(direction: body.routeDirection, speed: motion.speed * 1.15)
        }

        let slot = slotPoint(for: body, leader: leader, motion: motion, density: density, isIdle: isIdle)
        let toSlot = slot - body.position
        let distance = simd_length(toSlot)
        guard distance > (isIdle ? 0.35 : 0.1) else { return CrowdDesire() }

        var speed = min(distance / 0.5, motion.speed * 1.3)
        if leaderSpeed > 0.15 { speed = max(speed, min(leaderSpeed, motion.speed)) }
        return CrowdDesire(direction: toSlot / distance, speed: speed)
    }

    private func slotPoint(
        for body: CrowdBody,
        leader: CrowdBody,
        motion: CrowdPartyMotion,
        density: Double,
        isIdle: Bool
    ) -> SIMD2<Double> {
        let forward = motion.forward
        let left = SIMD2(-forward.y, forward.x)
        let lateral = CrowdSimulation.sideSpacing(density: density)

        let offset: SIMD2<Double>
        if isIdle {
            offset = body.idleOffset * 0.6
        } else if motion.walkers == 2 {
            offset = SIMD2(0, lateral)
        } else if motion.walkers == 3 {
            offset = SIMD2(-0.55, body.slotIndex == 1 ? lateral : -lateral)
        } else {
            let side = body.slotIndex == 1 ? lateral : (body.slotIndex == 2 ? -lateral : lateral / 2)
            offset = SIMD2(body.slotIndex >= 3 ? -1.0 : -0.5, side)
        }

        let slot = leader.position + forward * offset.x + left * offset.y
        return walls.wallDistance(at: slot) < 0.3 ? leader.position - forward * 0.7 : slot
    }

    private func collectNeighbors(ofBodyAt index: Int, into neighbors: inout [CrowdNeighbor]) {
        neighbors.removeAll(keepingCapacity: true)
        let body = bodies[index]
        var found = 0
        hash.forEachNearby(body.position) { other in
            guard other != index, found < Self.maxNeighbors else { return }
            let neighbor = bodies[other]
            let offset = neighbor.position - body.position
            guard simd_length_squared(offset) < Self.neighborRadiusSquared else { return }

            let isSameParty = neighbor.partyIndex == body.partyIndex
            let margin = isSameParty ? -0.05 : (neighbor.isStationary ? 0.25 : 0.1)
            found += 1
            neighbors.append(CrowdNeighbor(
                offset: offset,
                velocity: neighbor.isStationary ? .zero : neighbor.velocity * 0.5,
                combinedRadius: body.radius + neighbor.radius + margin,
                weight: isSameParty ? 0.4 : 1.4
            ))
        }
    }

    /// Tries seven headings at two speeds and keeps the cheapest: close to the wanted velocity,
    /// no collision soon, and away from walls.
    private func steer(_ body: CrowdBody, desire: CrowdDesire, neighbors: [CrowdNeighbor]) -> SIMD2<Double> {
        let wanted = desire.direction * desire.speed
        let wallDistance = walls.wallDistance(at: body.position)
        guard !neighbors.isEmpty || wallDistance < 0.8 else { return wanted }

        let baseHeading = atan2(wanted.y, wanted.x)
        var best = wanted
        var bestCost = Double.infinity
        for offset in Self.headingOffsets {
            for fraction in Self.speedFractions {
                let heading = baseHeading + offset
                let candidate = SIMD2(cos(heading), sin(heading)) * desire.speed * fraction
                let cost = steeringCost(
                    of: candidate,
                    body: body,
                    wanted: wanted,
                    wallDistance: wallDistance,
                    neighbors: neighbors
                )
                if cost < bestCost {
                    bestCost = cost
                    best = candidate
                }
            }
        }
        return best
    }

    private func steeringCost(
        of candidate: SIMD2<Double>,
        body: CrowdBody,
        wanted: SIMD2<Double>,
        wallDistance: Double,
        neighbors: [CrowdNeighbor]
    ) -> Double {
        var cost = simd_distance(candidate, wanted) + 0.25 * simd_distance(candidate, body.velocity)
        for neighbor in neighbors {
            let collisionTime = CrowdSimulation.timeToCollision(
                offset: neighbor.offset,
                relativeVelocity: candidate - neighbor.velocity,
                radius: neighbor.combinedRadius
            )
            if collisionTime < 2.5 { cost += neighbor.weight / (collisionTime + 0.25) }
        }
        if wallDistance < 0.8 {
            let ahead = walls.wallDistance(at: body.position + candidate * 0.6)
            if ahead < 0.2 { cost += 8 * (0.2 - ahead) + (ahead < 0 ? 10 : 0) }
        }
        return cost
    }
}
