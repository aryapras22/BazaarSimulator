import Foundation
import simd

struct CrowdNeighbor {
    let offset: SIMD2<Double>
    let velocity: SIMD2<Double>
    let combinedRadius: Double
    let weight: Double
}

private struct CrowdDesire {
    var direction = SIMD2<Double>.zero
    var speed = 0.0
}

extension CrowdSimulation {
    private static let headingOffsets = [0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4]
    private static let speedFractions = [1.0, 0.5]
    private static let maxNeighbors = 48
    private static let neighborRadiusSquared = 6.25

    /// Share of walking speed left at this density, from the Weidmann curve. People squeeze past and never stop dead.
    static func crowdFactor(density: Double) -> Double {
        guard density >= 0.05 else { return 1 }
        let factor = 1 - exp(-CrowdParameters.weidmannGamma * (1 / density - 1 / CrowdParameters.jamDensity))
        return max(CrowdParameters.minimumCrowdFactor, min(1, factor))
    }

    /// Side by side spacing of a walking group, closing up as the floor gets busy.
    static func sideSpacing(density: Double) -> Double {
        let span = CrowdParameters.busyDensity - CrowdParameters.quietDensity
        let busyness = min(1, max(0, (density - CrowdParameters.quietDensity) / span))
        return CrowdParameters.sideSpacingQuiet
            + (CrowdParameters.sideSpacingBusy - CrowdParameters.sideSpacingQuiet) * busyness
    }

    func moveAgents() {
        guard !agents.isEmpty else { return }
        spatialHash.rebuild(with: agents)
        let densities = localDensities()

        var velocities = [SIMD2<Double>](repeating: .zero, count: agents.count)
        for index in agents.indices where !agents[index].isSeated {
            velocities[index] = nextVelocity(ofAgentAt: index, density: densities[index])
        }

        let previous = agents.map(\.position)
        for index in agents.indices {
            agents[index].velocity = velocities[index]
            agents[index].position += velocities[index] * CrowdParameters.stepSeconds
        }
        for index in agents.indices where !agents[index].isSeated {
            separateOverlaps(ofAgentAt: index)
            pushOffWalls(agents[index])
            applyDoorRule(to: agents[index], from: previous[index])
        }
    }

    /// People per square metre around each agent. Seated people do not count.
    private func localDensities() -> [Double] {
        let radiusSquared = CrowdParameters.densityRadius * CrowdParameters.densityRadius
        let area = Double.pi * radiusSquared

        return agents.indices.map { index in
            let agent = agents[index]
            var people = agent.weight
            spatialHash.forEachNearby(agent.position) { other in
                guard other != index, !agents[other].isSeated else { return }
                if simd_distance_squared(agents[other].position, agent.position) < radiusSquared {
                    people += agents[other].weight
                }
            }
            return people / area
        }
    }

    private func nextVelocity(ofAgentAt index: Int, density: Double) -> SIMD2<Double> {
        let agent = agents[index]
        let party = agent.party
        var desire = agent === party.leader ? leaderDesire(party) : followerDesire(agent, density: density)
        desire.speed *= Self.crowdFactor(density: density)
        guard desire.speed >= 0.02 else { return .zero }

        collectNeighbors(ofAgentAt: index)
        let steered = steer(agent, desired: desire)
        var velocity = agent.velocity + (steered - agent.velocity) * min(1, CrowdParameters.stepSeconds / 0.35)
        let speedCap = party.speed * 1.35
        if simd_length(velocity) > speedCap { velocity = simd_normalize(velocity) * speedCap }
        return velocity
    }

    private func leaderDesire(_ party: CrowdParty) -> CrowdDesire {
        let leader = party.leader
        let field = targetField(of: party)
        let cell = world.cell(at: leader.position)

        switch party.state {
        case .walking:
            var speed = party.speed * world.cornerSpeedFactor(at: leader.position)
            let farthest = party.members.dropFirst()
                .filter { !$0.isSeated }
                .map { simd_distance($0.position, leader.position) }
                .max() ?? 0
            if farthest > 3.2 {
                speed *= 0.55
            } else if farthest > 2.2 {
                speed *= 0.85
            }
            return CrowdDesire(direction: field.direction(atCell: cell), speed: speed)
        case .queueing:
            guard case .booth(let booth, _) = party.target else { return CrowdDesire() }
            let rank = max(0, queues[booth].firstIndex { $0 === party } ?? 0)
            guard Double(field.costs[cell]) > queueSpot(booth: booth, rank: rank) + 0.15 else { return CrowdDesire() }
            return CrowdDesire(direction: field.direction(atCell: cell), speed: min(party.speed, 0.9))
        case .visiting, .seated:
            return CrowdDesire()
        }
    }

    /// A follower heads for its slot beside the leader, or takes the legal route when a wall is between them.
    private func followerDesire(_ agent: CrowdAgent, density: Double) -> CrowdDesire {
        let party = agent.party
        let leader = party.leader
        let isStill = party.state == .visiting || (party.state == .queueing && party.isHoldingInQueue)
        let leaderSpeed = simd_length(leader.velocity)
        let isIdle = isStill || leaderSpeed < 0.15

        guard world.hasLineOfSight(from: agent.position, to: leader.position) else {
            let direction = targetField(of: party).direction(atCell: world.cell(at: agent.position))
            return CrowdDesire(direction: direction, speed: party.speed * 1.15)
        }

        let slot = slotPoint(for: agent, density: density, isIdle: isIdle, leaderSpeed: leaderSpeed)
        let toSlot = slot - agent.position
        let distance = simd_length(toSlot)
        guard distance > (isIdle ? 0.35 : 0.1) else { return CrowdDesire() }

        var speed = min(distance / 0.5, party.speed * 1.3)
        if leaderSpeed > 0.15 { speed = max(speed, min(leaderSpeed, party.speed)) }
        return CrowdDesire(direction: toSlot / distance, speed: speed)
    }

    private func slotPoint(
        for agent: CrowdAgent,
        density: Double,
        isIdle: Bool,
        leaderSpeed: Double
    ) -> SIMD2<Double> {
        let party = agent.party
        let leader = party.leader
        if leaderSpeed > 0.15 { party.heldForward = leader.velocity / leaderSpeed }
        let forward = party.heldForward ?? SIMD2(1, 0)
        let left = SIMD2(-forward.y, forward.x)

        let lateral = Self.sideSpacing(density: density)
        let offset: SIMD2<Double>
        if isIdle {
            offset = agent.idleOffset * 0.6
        } else if party.walkers == 2 {
            offset = SIMD2(0, lateral)
        } else if party.walkers == 3 {
            offset = SIMD2(-0.55, agent.slotIndex == 1 ? lateral : -lateral)
        } else {
            let side = agent.slotIndex == 1 ? lateral : (agent.slotIndex == 2 ? -lateral : lateral / 2)
            offset = SIMD2(agent.slotIndex >= 3 ? -1.0 : -0.5, side)
        }

        let slot = leader.position + forward * offset.x + left * offset.y
        return world.wallDistance(at: slot) < 0.3 ? leader.position - forward * 0.7 : slot
    }

    private func isStationary(_ agent: CrowdAgent) -> Bool {
        let state = agent.party.state
        return agent.isSeated || state == .visiting || (state == .queueing && agent.party.isHoldingInQueue)
    }

    private func collectNeighbors(ofAgentAt index: Int) {
        neighbors.removeAll(keepingCapacity: true)
        let agent = agents[index]
        spatialHash.forEachNearby(agent.position) { other in
            guard other != index, neighbors.count < Self.maxNeighbors else { return }
            let neighbor = agents[other]
            let offset = neighbor.position - agent.position
            guard simd_length_squared(offset) < Self.neighborRadiusSquared else { return }

            let stationary = isStationary(neighbor)
            let isSameParty = neighbor.party === agent.party
            neighbors.append(CrowdNeighbor(
                offset: offset,
                velocity: stationary ? .zero : neighbor.velocity * 0.5,
                combinedRadius: agent.radius + neighbor.radius + (isSameParty ? -0.05 : (stationary ? 0.25 : 0.1)),
                weight: isSameParty ? 0.4 : 1.4
            ))
        }
    }

    /// Tries seven headings at two speeds and keeps the cheapest: close to the wanted velocity,
    /// no collision soon, and away from walls.
    private func steer(_ agent: CrowdAgent, desired: CrowdDesire) -> SIMD2<Double> {
        let wanted = desired.direction * desired.speed
        let wallDistance = world.wallDistance(at: agent.position)
        guard !neighbors.isEmpty || wallDistance < 0.8 else { return wanted }

        let baseHeading = atan2(wanted.y, wanted.x)
        var best = wanted
        var bestCost = Double.infinity
        for offset in Self.headingOffsets {
            for fraction in Self.speedFractions {
                let heading = baseHeading + offset
                let candidate = SIMD2(cos(heading), sin(heading)) * desired.speed * fraction
                let cost = steeringCost(of: candidate, for: agent, wanted: wanted, wallDistance: wallDistance)
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
        for agent: CrowdAgent,
        wanted: SIMD2<Double>,
        wallDistance: Double
    ) -> Double {
        var cost = simd_distance(candidate, wanted) + 0.25 * simd_distance(candidate, agent.velocity)
        for neighbor in neighbors {
            let collisionTime = Self.timeToCollision(
                offset: neighbor.offset,
                relativeVelocity: candidate - neighbor.velocity,
                radius: neighbor.combinedRadius
            )
            if collisionTime < 2.5 { cost += neighbor.weight / (collisionTime + 0.25) }
        }
        if wallDistance < 0.8 {
            let ahead = world.wallDistance(at: agent.position + candidate * 0.6)
            if ahead < 0.2 { cost += 8 * (0.2 - ahead) + (ahead < 0 ? 10 : 0) }
        }
        return cost
    }

    /// Seconds until two circles touch, 0 if already overlapping and closing, infinity if they never meet.
    static func timeToCollision(offset: SIMD2<Double>, relativeVelocity: SIMD2<Double>, radius: Double) -> Double {
        let gap = simd_length_squared(offset) - radius * radius
        let quadratic = simd_length_squared(relativeVelocity)
        let linear = -2 * simd_dot(offset, relativeVelocity)
        if gap < 0 { return linear < 0 ? 0 : .infinity }
        if quadratic < 1e-6 || linear >= 0 { return .infinity }
        let discriminant = linear * linear - 4 * quadratic * gap
        if discriminant < 0 { return .infinity }
        return (-linear - discriminant.squareRoot()) / (2 * quadratic)
    }

    // MARK: - Constraints

    private func separateOverlaps(ofAgentAt index: Int) {
        let agent = agents[index]
        spatialHash.forEachNearby(agent.position) { other in
            guard other > index, !agents[other].isSeated else { return }
            let neighbor = agents[other]
            let offset = neighbor.position - agent.position
            let distance = simd_length(offset)
            let minimum = (agent.radius + neighbor.radius) * 0.97

            if distance <= 1e-4 {
                agent.position += SIMD2(Double(index % 3 - 1), Double(index % 5 - 2)) * 0.01
            } else if distance < minimum {
                let push = offset / distance * (minimum - distance)
                let agentIsFixed = isStationary(agent)
                let neighborIsFixed = isStationary(neighbor)
                let agentShare = agentIsFixed && !neighborIsFixed ? 0.0 : (neighborIsFixed && !agentIsFixed ? 1.0 : 0.5)
                agent.position -= push * agentShare
                neighbor.position += push * (1 - agentShare)
            }
        }
    }

    private func pushOffWalls(_ agent: CrowdAgent) {
        let distance = world.wallDistance(at: agent.position)
        let wanted = agent.radius * 0.85
        guard distance < wanted else { return }
        let gradient = world.wallGradient(at: agent.position)
        let length = simd_length(gradient)
        guard length > 0 else { return }
        agent.position += gradient / length * min(wanted - distance, 0.25)
    }

    /// Stepping into a one-way door from its wrong side is undone.
    func applyDoorRule(to agent: CrowdAgent, from previous: SIMD2<Double>) {
        guard let rule = world.doorRules[world.cell(at: agent.position)],
              world.doorRules[world.cell(at: previous)] == nil else { return }
        let inwardMove = simd_dot(agent.position - previous, rule.inward)
        guard rule.forbidsWalkingIn ? inwardMove > 0 : inwardMove < 0 else { return }
        agent.position -= rule.inward * inwardMove
        agent.velocity -= rule.inward * simd_dot(agent.velocity, rule.inward)
    }
}
