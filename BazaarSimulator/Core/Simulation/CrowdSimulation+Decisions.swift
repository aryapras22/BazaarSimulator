import Foundation
import simd

nonisolated extension CrowdSimulation {
    // MARK: - Choosing where to go

    func pickTarget(_ party: CrowdParty) {
        party.restartProgress(at: time)
        while let booth = party.plan.first {
            if party.visited.contains(booth) {
                party.plan.removeFirst()
                continue
            }
            party.target = .booth(booth, .planned)
            return
        }
        if !party.isGoalDriven && !party.hasWalkedTheHall {
            // A stroller walks the whole hall: it heads for the farthest booth it has not seen, then leaves.
            let farthest = world.booths.indices
                .filter { world.booths[$0].isReachable(fromGate: party.gate) && !party.visited.contains($0) }
                .max { world.booths[$0].gateCosts[party.gate] < world.booths[$1].gateCosts[party.gate] }
            if let farthest {
                party.target = .booth(farthest, .passingThrough)
                return
            }
            party.hasWalkedTheHall = true
        }
        party.target = .exit
    }

    func targetField(of party: CrowdParty) -> CrowdFlowField {
        switch party.target {
        case .exit: return world.flowField(to: .exit)
        case .table(let table): return world.flowField(to: .table(table))
        case .booth(let booth, _): return world.flowField(to: .booth(booth))
        }
    }

    /// How far along the queue this rank stands, measured from the counter.
    func queueSpot(booth: Int, rank: Int) -> Double {
        queues[booth].prefix(rank).reduce(0.3) { $0 + 0.35 + 0.3 * Double($1.walkers) }
    }

    /// A party joins a queue where the queue ends, not at the counter.
    private func arrivalDistance(for target: CrowdTarget) -> Double {
        switch target {
        case .table: return 0.35
        case .exit: return 0.1
        case .booth(_, .passingThrough): return 1.5
        case .booth(let booth, _):
            let isBusy = !queues[booth].isEmpty || browsers[booth].count >= world.booths[booth].capacity
            return isBusy ? queueSpot(booth: booth, rank: queues[booth].count) + 0.2 : 0.3
        }
    }

    // MARK: - Decisions, every half second per party

    func think(_ party: CrowdParty) {
        if party.state == .visiting || party.state == .seated {
            if time >= party.endTime { finishStop(party) }
            return
        }
        let leader = party.leader
        if simd_length(leader.velocity) > 0.12 {
            party.heading = atan2(leader.velocity.y, leader.velocity.x)
        }
        if party.state == .queueing {
            thinkInQueue(party)
            return
        }
        considerDetour(party)
        advanceTowardTarget(party)
    }

    private func thinkInQueue(_ party: CrowdParty) {
        guard case .booth(let booth, _) = party.target,
              let rank = queues[booth].firstIndex(where: { $0 === party }) else {
            party.state = .walking
            return
        }
        if time - (party.queuedAt ?? time) > maxQueueWaitSeconds {
            queues[booth].remove(at: rank)
            party.visited.insert(booth)
            party.queuedAt = nil
            party.state = .walking
            pickTarget(party)
            return
        }
        let cost = Double(targetField(of: party).costs[world.cell(at: party.leader.position)])
        if rank == 0 && browsers[booth].count < world.booths[booth].capacity && cost <= 0.9 {
            startVisit(party, booth: booth)
        }
    }

    /// A buyer can be pulled into a more attractive booth, and a stroller stops now and then at any booth in view.
    func considerDetour(_ party: CrowdParty) {
        if party.isGoalDriven {
            guard case .booth(let planned, .planned) = party.target,
                  party.detours < CrowdParameters.maxDetours,
                  let best = bestVisibleBooth(for: party, strongerThan: party.loyalty),
                  best != planned else { return }
            party.plan.removeAll { $0 == planned }
            party.target = .booth(best, .detour)
            party.detours += 1
            party.restartProgress(at: time)
            return
        }

        guard party.stopoversLeft > 0, let best = bestVisibleBooth(for: party) else { return }
        switch party.target {
        case .exit, .booth(_, .planned), .booth(_, .passingThrough):
            if case .booth(best, _) = party.target { return }
            party.target = .booth(best, .stopover)
            party.restartProgress(at: time)
        default:
            return
        }
    }

    private func advanceTowardTarget(_ party: CrowdParty) {
        let cost = Double(targetField(of: party).costs[world.cell(at: party.leader.position)])
        guard cost.isFinite else {
            abandonTarget(party)
            return
        }
        if cost <= arrivalDistance(for: party.target) {
            arrive(party)
            return
        }
        if cost < party.lastCost - 0.8 {
            party.lastCost = cost
            party.lastProgress = time
        } else if time - party.lastProgress > CrowdParameters.stuckSeconds {
            abandonTarget(party)
        }
    }

    private func abandonTarget(_ party: CrowdParty) {
        switch party.target {
        case .exit:
            removeParty(party)
        case .table(let table):
            tableOccupants[table] = nil
            pickTarget(party)
        case .booth(let booth, _):
            party.visited.insert(booth)
            pickTarget(party)
        }
    }

    // MARK: - Arriving and leaving a stop

    func arrive(_ party: CrowdParty) {
        switch party.target {
        case .exit:
            removeParty(party)
        case .table(let table):
            sitDown(party, table: table)
        case .booth(_, .passingThrough):
            party.hasWalkedTheHall = true
            pickTarget(party)
        case .booth(let booth, _):
            arriveAtBooth(party, booth: booth)
        }
    }

    private func arriveAtBooth(_ party: CrowdParty, booth: Int) {
        let hasRoom = browsers[booth].count < world.booths[booth].capacity
        if hasRoom && (queues[booth].isEmpty || queues[booth][0] === party) {
            startVisit(party, booth: booth)
            return
        }
        guard !queues[booth].contains(where: { $0 === party }) else { return }
        if queues[booth].count >= maxQueueLength {
            stats.balks += 1
            party.visited.insert(booth)
            pickTarget(party)
            return
        }
        queues[booth].append(party)
        party.state = .queueing
        party.queuedAt = time
    }

    private func sitDown(_ party: CrowdParty, table: Int) {
        let leaderPosition = party.leader.position
        // Wait until the whole party has caught up.
        guard party.members.allSatisfy({ simd_distance($0.position, leaderPosition) <= 3.5 }) else { return }

        party.state = .seated
        party.endTime = time + max(30, party.eatSeconds)
        party.seat = table
        let seats = [SIMD2(-0.25, -0.25), SIMD2(0.25, -0.25), SIMD2(-0.25, 0.25), SIMD2(0.25, 0.25)]
        for (index, member) in party.members.enumerated() {
            member.positionBeforeSeat = member.position
            member.position = world.tables[table].footprint.center + seats[index % 4] * world.tables[table].size
            member.velocity = .zero
            member.isSeated = true
        }
    }

    func startVisit(_ party: CrowdParty, booth: Int) {
        queues[booth].removeAll { $0 === party }
        party.queuedAt = nil
        browsers[booth].append(party)
        party.state = .visiting
        party.endTime = time + dwellSeconds(for: party, booth: booth)
        party.currentBooth = booth
        if case .booth(_, let reason) = party.target { party.currentReason = reason }
        for member in party.members { member.velocity = .zero }
    }

    private func dwellSeconds(for party: CrowdParty, booth: Int) -> Double {
        if case .booth(_, .stopover) = party.target {
            return choiceRandom.randomDouble(in: CrowdParameters.stopoverSeconds)
        }
        if world.booths[booth].isFood {
            party.willSit = choiceRandom.nextDouble() < party.persona.sitChance
            party.eatSeconds = party.willSit
                ? exp(log(CrowdParameters.medianEatSeconds) + 0.4 * choiceRandom.nextGaussian())
                : 0
        }
        return choiceRandom.randomDouble(in: party.persona.dwellSeconds)
    }

    func finishStop(_ party: CrowdParty) {
        if party.state == .seated {
            standUp(party)
            return
        }
        guard let booth = party.currentBooth else {
            party.state = .walking
            pickTarget(party)
            return
        }
        browsers[booth].removeAll { $0 === party }
        party.currentBooth = nil
        party.visited.insert(booth)
        party.state = .walking

        if party.currentReason == .stopover {
            party.stopoversLeft -= 1
        } else {
            stats.visits += party.people
            if world.booths[booth].isFood && party.willSit, let table = nearestFreeTable(to: party) {
                tableOccupants[table] = party
                party.target = .table(table)
                party.restartProgress(at: time)
                return
            }
        }
        pickTarget(party)
    }

    private func standUp(_ party: CrowdParty) {
        if let seat = party.seat { tableOccupants[seat] = nil }
        party.seat = nil
        for member in party.members {
            member.isSeated = false
            member.position = member.positionBeforeSeat
        }
        party.state = .walking
        pickTarget(party)
    }

    private func nearestFreeTable(to party: CrowdParty) -> Int? {
        world.tables.indices
            .filter { tableOccupants[$0] == nil && world.tables[$0].isReachable }
            .min {
                simd_distance(world.tables[$0].footprint.center, party.leader.position)
                    < simd_distance(world.tables[$1].footprint.center, party.leader.position)
            }
    }

    func removeParty(_ party: CrowdParty) {
        let memberIDs = Set(party.members.map(\.id))
        agents.removeAll { memberIDs.contains($0.id) }
        parties.removeAll { $0 === party }
        if let booth = party.currentBooth { browsers[booth].removeAll { $0 === party } }
        if case .booth(let booth, _) = party.target { queues[booth].removeAll { $0 === party } }
        if let seat = party.seat { tableOccupants[seat] = nil }
        stats.departedPeople += party.people
        stats.staySeconds += (time - party.enteredAt) * Double(party.people)
    }

    // MARK: - Vision

    /// A booth is seen when part of its influence circle is inside the view cone with a clear line of sight.
    func bestVisibleBooth(for party: CrowdParty, strongerThan minimumPull: Double = 0) -> Int? {
        let leaderPosition = party.leader.position
        var best: (booth: Int, reach: Double)?

        for booth in world.booths.indices
        where world.booths[booth].pull > minimumPull
            && world.booths[booth].isReachable(fromGate: party.gate)
            && !party.visited.contains(booth) {
            guard let reach = visibleReach(of: booth, from: leaderPosition, heading: party.heading) else { continue }
            guard let current = best else {
                best = (booth, reach)
                continue
            }
            let pull = world.booths[booth].pull
            let currentPull = world.booths[current.booth].pull
            if pull > currentPull || (pull == currentPull && reach < current.reach) {
                best = (booth, reach)
            }
        }
        return best?.booth
    }

    /// The distance left to the booth's influence circle, or nil when the booth is out of sight.
    private func visibleReach(of booth: Int, from position: SIMD2<Double>, heading: Double) -> Double? {
        let influence = CrowdParameters.influenceRadius
        let nearest = world.booths[booth].footprint.nearestPoint(to: position)
        let delta = nearest - position
        let distance = simd_length(delta)
        let reach = max(0, distance - influence)
        guard reach <= CrowdParameters.viewDepth else { return nil }
        guard distance > 0.3 else { return reach }

        var angleOff = abs(atan2(delta.y, delta.x) - heading)
        if angleOff > .pi { angleOff = 2 * .pi - angleOff }
        let halfView = CrowdParameters.viewAngleDegrees * .pi / 360
        let tolerance = distance > influence ? asin(min(1, influence / distance)) : .pi
        guard angleOff <= halfView + tolerance else { return nil }

        let standOff = max(0.35, min(influence, distance - 0.05))
        return world.hasLineOfSight(from: position, to: nearest - delta / distance * standOff) ? reach : nil
    }
}
