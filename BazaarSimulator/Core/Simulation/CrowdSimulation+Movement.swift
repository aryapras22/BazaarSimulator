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
    private static let chunkSize = 32
    private static let minimumAgentsForThreads = 64

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

    func moveAgents() {
        guard !agents.isEmpty else { return }
        let prepared = makeBodies()
        var bodies = prepared.bodies
        spatialHash.rebuild(with: bodies)
        let velocities = steeredVelocities(bodies: bodies, motions: prepared.motions)

        let previous = bodies.map(\.position)
        for index in bodies.indices where !bodies[index].isSeated {
            bodies[index].velocity = velocities[index]
            bodies[index].position += velocities[index] * CrowdParameters.stepSeconds
        }
        var nearby: [Int] = []
        for index in bodies.indices where !bodies[index].isSeated {
            separateOverlaps(ofBodyAt: index, in: &bodies, nearby: &nearby)
            pushOffWalls(&bodies[index])
            var body = bodies[index]
            applyDoorRule(position: &body.position, velocity: &body.velocity, from: previous[index])
            bodies[index] = body
        }
        for index in agents.indices {
            agents[index].position = bodies[index].position
            agents[index].velocity = bodies[index].velocity
        }
    }

    private func makeBodies() -> (bodies: [CrowdBody], motions: [CrowdPartyMotion]) {
        var bodies = [CrowdBody](repeating: CrowdBody(), count: agents.count)
        var motions = [CrowdPartyMotion](repeating: CrowdPartyMotion(), count: parties.count)
        for (index, agent) in agents.enumerated() { agent.bodyIndex = index }

        for (partyIndex, party) in parties.enumerated() {
            let field = party.state == .seated ? nil : targetField(of: party)
            motions[partyIndex] = motion(of: party, field: field)
            for member in party.members {
                bodies[member.bodyIndex] = CrowdBody(
                    position: member.position,
                    velocity: member.velocity,
                    routeDirection: field?.direction(atCell: world.cell(at: member.position)) ?? .zero,
                    idleOffset: member.idleOffset,
                    radius: member.radius,
                    weight: member.weight,
                    partyIndex: partyIndex,
                    slotIndex: member.slotIndex,
                    isSeated: member.isSeated,
                    isStationary: member.isSeated || motions[partyIndex].isStill,
                    isLeader: member === party.leader
                )
            }
        }
        return (bodies, motions)
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
            let farthest = party.members.dropFirst()
                .filter { !$0.isSeated }
                .map { simd_distance($0.position, leader.position) }
                .max() ?? 0
            if farthest > 3.2 {
                speed *= 0.55
            } else if farthest > 2.2 {
                speed *= 0.85
            }
            return speed
        case .queueing:
            guard case .booth(let booth, _) = party.target, let field else { return 0 }
            let rank = max(0, queues[booth].firstIndex { $0 === party } ?? 0)
            let cost = Double(field.costs[world.cell(at: leader.position)])
            return cost > queueSpot(booth: booth, rank: rank) + 0.15 ? min(party.speed, 0.9) : 0
        case .visiting, .seated:
            return 0
        }
    }

    /// Every velocity depends only on the state at the start of the step, so the agents can be
    /// computed on separate cores in any order and the run stays repeatable.
    private func steeredVelocities(bodies: [CrowdBody], motions: [CrowdPartyMotion]) -> [SIMD2<Double>] {
        let count = bodies.count
        let chunks = count < Self.minimumAgentsForThreads ? 1 : (count + Self.chunkSize - 1) / Self.chunkSize
        let chunkSize = chunks == 1 ? count : Self.chunkSize
        var velocities = [SIMD2<Double>](repeating: .zero, count: count)

        bodies.withUnsafeBufferPointer { bodyBuffer in
            motions.withUnsafeBufferPointer { motionBuffer in
                velocities.withUnsafeMutableBufferPointer { output in
                    let pass = CrowdSteeringPass(
                        bodies: bodyBuffer,
                        motions: motionBuffer,
                        hash: spatialHash,
                        walls: world.walls
                    )
                    guard let target = output.baseAddress else { return }
                    DispatchQueue.concurrentPerform(iterations: chunks) { chunk in
                        var neighbors: [CrowdNeighbor] = []
                        neighbors.reserveCapacity(CrowdSteeringPass.maxNeighbors)
                        for index in (chunk * chunkSize)..<min(count, (chunk + 1) * chunkSize)
                        where !bodyBuffer[index].isSeated {
                            target[index] = pass.velocity(ofBodyAt: index, neighbors: &neighbors)
                        }
                    }
                }
            }
        }
        return velocities
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
            let minimum = (bodies[index].radius + bodies[other].radius) * 0.97

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
        let wanted = body.radius * 0.85
        guard distance < wanted else { return }
        let gradient = world.walls.wallGradient(at: body.position)
        let length = simd_length(gradient)
        guard length > 0 else { return }
        body.position += gradient / length * min(wanted - distance, 0.25)
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
