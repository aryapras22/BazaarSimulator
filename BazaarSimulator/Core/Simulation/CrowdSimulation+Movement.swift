import Foundation
import simd

/// A value copy of one agent for a single step, so the parallel pass touches no shared objects.
nonisolated struct CrowdBody {
    var position = SIMD2<Double>.zero
    var velocity = SIMD2<Double>.zero
    var routeDirection = SIMD2<Double>.zero
    var idleOffset = SIMD2<Double>.zero
    var radius = 0.0
    var weight = 0.0
    var partyIndex = 0
    var slotIndex = 0
    var isSeated = false
    var isStationary = false
    var isLeader = false
}

/// What the members of one party need to know about it during a step.
nonisolated struct CrowdPartyMotion {
    var leaderIndex = 0
    var walkers = 0
    var speed = 0.0
    var leaderWalkSpeed = 0.0
    var forward = SIMD2<Double>(1, 0)
    var isStill = false
}

nonisolated extension CrowdSimulation {
    private static let chunkSize = CrowdParameters.parallelChunkSize
    private static let minimumAgentsForThreads = CrowdParameters.minimumAgentsForThreads

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

    /// Helbing Social Force between two pedestrians, weighted by directional field of view (anisotropy).
    static func socialRepulsionForce(
        offsetToNeighbor: SIMD2<Double>,
        combinedRadius: Double,
        forwardDirection: SIMD2<Double>
    ) -> SIMD2<Double> {
        let dist = simd_length(offsetToNeighbor)
        guard dist > 1e-5 else { return .zero }
        let awayUnit = -offsetToNeighbor / dist
        let penetration = combinedRadius - dist
        let magnitude = CrowdParameters.socialForceStrength * exp(penetration / CrowdParameters.socialForceRangeM)

        // Anisotropic vision weight: stronger response to pedestrians in front than behind.
        let forwardLen = simd_length(forwardDirection)
        let cosTheta = forwardLen > 1e-4 ? simd_dot(forwardDirection / forwardLen, -awayUnit) : 1.0
        let lambda = CrowdParameters.socialForceAnisotropyLambda
        let directionalWeight = lambda + (1.0 - lambda) * ((1.0 + cosTheta) * 0.5)
        return awayUnit * (magnitude * directionalWeight)
    }

    func moveAgents() {
        guard !agents.isEmpty else { return }
        populateScratchBuffers()
        spatialHash.rebuild(with: bodyScratch)
        computeSteeredVelocities()

        previousPosScratch.removeAll(keepingCapacity: true)
        for index in bodyScratch.indices {
            previousPosScratch.append(bodyScratch[index].position)
            if !bodyScratch[index].isSeated {
                bodyScratch[index].velocity = velocityScratch[index]
                bodyScratch[index].position += velocityScratch[index] * CrowdParameters.stepSeconds
            }
        }
        for index in bodyScratch.indices where !bodyScratch[index].isSeated {
            separateOverlaps(ofBodyAt: index, in: &bodyScratch, nearby: &nearbyScratch)
            pushOffWalls(&bodyScratch[index])
            var body = bodyScratch[index]
            applyDoorRule(position: &body.position, velocity: &body.velocity, from: previousPosScratch[index])
            bodyScratch[index] = body
        }
        for index in agents.indices {
            agents[index].position = bodyScratch[index].position
            agents[index].velocity = bodyScratch[index].velocity
        }
    }

    private func populateScratchBuffers() {
        bodyScratch.removeAll(keepingCapacity: true)
        if bodyScratch.capacity < agents.count { bodyScratch.reserveCapacity(agents.count) }
        for _ in 0..<agents.count { bodyScratch.append(CrowdBody()) }

        motionScratch.removeAll(keepingCapacity: true)
        if motionScratch.capacity < parties.count { motionScratch.reserveCapacity(parties.count) }

        for (index, agent) in agents.enumerated() { agent.bodyIndex = index }

        for (partyIndex, party) in parties.enumerated() {
            let field = party.state == .seated ? nil : targetField(of: party)
            let partyMotion = motion(of: party, field: field)
            motionScratch.append(partyMotion)
            for member in party.members {
                bodyScratch[member.bodyIndex] = CrowdBody(
                    position: member.position,
                    velocity: member.velocity,
                    routeDirection: field?.direction(atCell: world.cell(at: member.position)) ?? .zero,
                    idleOffset: member.idleOffset,
                    radius: member.radius,
                    weight: member.weight,
                    partyIndex: partyIndex,
                    slotIndex: member.slotIndex,
                    isSeated: member.isSeated,
                    isStationary: member.isSeated || partyMotion.isStill,
                    isLeader: member === party.leader
                )
            }
        }
    }

    private func motion(of party: CrowdParty, field: CrowdFlowField?) -> CrowdPartyMotion {
        let leader = party.leader
        let leaderSpeed = simd_length(leader.velocity)
        if leaderSpeed > 0.15 { party.heldForward = leader.velocity / leaderSpeed }
        return CrowdPartyMotion(
            leaderIndex: leader.bodyIndex,
            walkers: party.walkers,
            speed: party.speed,
            leaderWalkSpeed: leaderWalkSpeed(of: party, field: field),
            forward: party.heldForward ?? SIMD2(1, 0),
            isStill: party.state == .visiting || (party.state == .queueing && party.isHoldingInQueue)
        )
    }

    private func leaderWalkSpeed(of party: CrowdParty, field: CrowdFlowField?) -> Double {
        let leader = party.leader
        switch party.state {
        case .walking:
            var speed = party.speed * world.cornerSpeedFactor(at: leader.position)
            speed *= groupLagFactor(for: party, leaderPosition: leader.position)
            speed *= party.grazingSpeedFactor
            speed *= fatigueFactor(for: party)
            return speed
        case .queueing:
            guard case .booth(let booth, _) = party.target, let field else { return 0 }
            let rank = max(0, queues[booth].firstIndex { $0 === party } ?? 0)
            let cost = Double(field.costs[world.cell(at: leader.position)])
            let holdThreshold = queueSpot(booth: booth, rank: rank) + CrowdParameters.queueHoldToleranceM
            return cost > holdThreshold ? min(party.speed, CrowdParameters.queueAdvanceMaxSpeed) : 0
        case .visiting, .seated:
            return 0
        }
    }

    /// Slows the party leader down when group members lag behind in busy corridors.
    private func groupLagFactor(for party: CrowdParty, leaderPosition: SIMD2<Double>) -> Double {
        guard party.members.count > 1 else { return 1.0 }
        var farthest = 0.0
        for member in party.members.dropFirst() where !member.isSeated {
            farthest = max(farthest, simd_distance(member.position, leaderPosition))
        }
        if farthest > CrowdParameters.leaderFarLagDistanceM {
            return CrowdParameters.leaderFarLagSpeedFactor
        } else if farthest > CrowdParameters.leaderNearLagDistanceM {
            return CrowdParameters.leaderNearLagSpeedFactor
        }
        return 1.0
    }

    /// Fatigue rule: visitors who have spent a long time in the bazaar walk slightly slower.
    private func fatigueFactor(for party: CrowdParty) -> Double {
        let stayDuration = time - party.enteredAt
        guard stayDuration > CrowdParameters.fatigueOnsetSeconds else { return 1.0 }
        let extraHours = min(1.0, (stayDuration - CrowdParameters.fatigueOnsetSeconds) / 3600.0)
        return 1.0 - (1.0 - CrowdParameters.fatigueMaxSlowdownFactor) * extraHours
    }

    /// Every velocity depends only on the state at the start of the step, so the agents can be
    /// computed on separate cores in any order and the run stays repeatable.
    private func computeSteeredVelocities() {
        let count = bodyScratch.count
        velocityScratch.removeAll(keepingCapacity: true)
        if velocityScratch.capacity < count { velocityScratch.reserveCapacity(count) }
        for _ in 0..<count { velocityScratch.append(.zero) }

        let chunks = count < Self.minimumAgentsForThreads ? 1 : (count + Self.chunkSize - 1) / Self.chunkSize
        let chunkSize = chunks == 1 ? count : Self.chunkSize
        if neighborScratch.capacity < CrowdSteeringPass.maxNeighbors {
            neighborScratch.reserveCapacity(CrowdSteeringPass.maxNeighbors)
        }

        bodyScratch.withUnsafeBufferPointer { bodyBuffer in
            motionScratch.withUnsafeBufferPointer { motionBuffer in
                velocityScratch.withUnsafeMutableBufferPointer { output in
                    let pass = CrowdSteeringPass(
                        bodies: bodyBuffer,
                        motions: motionBuffer,
                        hash: spatialHash,
                        walls: world.walls
                    )
                    guard let target = output.baseAddress else { return }
                    if chunks == 1 {
                        for index in 0..<count where !bodyBuffer[index].isSeated {
                            target[index] = pass.velocity(ofBodyAt: index, neighbors: &neighborScratch)
                        }
                    } else {
                        DispatchQueue.concurrentPerform(iterations: chunks) { chunk in
                            var localNeighbors: [CrowdNeighbor] = []
                            localNeighbors.reserveCapacity(CrowdSteeringPass.maxNeighbors)
                            for index in (chunk * chunkSize)..<min(count, (chunk + 1) * chunkSize)
                            where !bodyBuffer[index].isSeated {
                                target[index] = pass.velocity(ofBodyAt: index, neighbors: &localNeighbors)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Constraints

    private func separateOverlaps(ofBodyAt index: Int, in bodies: inout [CrowdBody], nearby: inout [Int]) {
        nearby.removeAll(keepingCapacity: true)
        spatialHash.forEachNearby(bodies[index].position) { other in
            if other > index && !bodies[other].isSeated { nearby.append(other) }
        }

        for other in nearby {
            let offset = bodies[other].position - bodies[index].position
            let distance = simd_length(offset)
            let minimum = (bodies[index].radius + bodies[other].radius) * CrowdParameters.overlapSeparationFactor

            if distance <= 1e-4 {
                bodies[index].position += SIMD2(Double(index % 3 - 1), Double(index % 5 - 2)) * 0.01
            } else if distance < minimum {
                let push = offset / distance * (minimum - distance)
                let isFixed = bodies[index].isStationary
                let otherIsFixed = bodies[other].isStationary
                let share = isFixed && !otherIsFixed ? 0.0 : (otherIsFixed && !isFixed ? 1.0 : 0.5)
                bodies[index].position -= push * share
                bodies[other].position += push * (1 - share)
            }
        }
    }

    private func pushOffWalls(_ body: inout CrowdBody) {
        let distance = world.walls.wallDistance(at: body.position)
        let wanted = body.radius * CrowdParameters.wallClearanceFactor
        guard distance < wanted else { return }
        let gradient = world.walls.wallGradient(at: body.position)
        let length = simd_length(gradient)
        if length > 0 {
            body.position += gradient / length * min(wanted - distance, CrowdParameters.maxWallPushPerStepM)
        }
        if !world.walls.isFree(body.position) {
            body.position = world.nearestFreePoint(to: body.position)
        }
    }

    /// Stepping into a one-way door from its wrong side is undone.
    func applyDoorRule(position: inout SIMD2<Double>, velocity: inout SIMD2<Double>, from previous: SIMD2<Double>) {
        guard !world.doorRules.isEmpty,
              let rule = world.doorRules[world.cell(at: position)],
              world.doorRules[world.cell(at: previous)] == nil else { return }
        let inwardMove = simd_dot(position - previous, rule.inward)
        guard rule.forbidsWalkingIn ? inwardMove > 0 : inwardMove < 0 else { return }
        position -= rule.inward * inwardMove
        velocity -= rule.inward * simd_dot(velocity, rule.inward)
    }
}
