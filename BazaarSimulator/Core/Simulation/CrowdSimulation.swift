import Foundation
import simd

/// Visitor behaviour on one layout: who arrives, what they decide and how they move.
nonisolated final class CrowdSimulation {
    let world: CrowdWorld
    let totalVisitors: Int
    let maxQueueLength: Int
    let maxQueueWaitSeconds: Double
    /// Parties arriving each second. A measured run changes it through the day to follow the peaks.
    var arrivalRatePerSecond: Double
    let personaWeights: [(persona: CrowdPersona, weight: Double)]

    var stepCount = 0
    var stats = CrowdStats()
    var agents: [CrowdAgent] = []
    var parties: [CrowdParty] = []
    var waitingOutside: [[CrowdPartyDraw]]
    var gateTokens: [Double]
    var browsers: [[CrowdParty]]
    var queues: [[CrowdParty]]
    var tableOccupants: [CrowdParty?]
    var arrivalRandom: SeededRandom
    var traitRandom: SeededRandom
    var choiceRandom: SeededRandom
    var spatialHash: CrowdSpatialHash

    var bodyScratch: [CrowdBody] = []
    var motionScratch: [CrowdPartyMotion] = []
    var velocityScratch: [SIMD2<Double>] = []
    var previousPosScratch: [SIMD2<Double>] = []
    var nearbyScratch: [Int] = []
    var neighborScratch: [CrowdNeighbor] = []

    /// The event is about to close: everyone inside heads for the exit and nobody else comes in.
    private(set) var isClosing = false
    private var nextArrival = 0.0
    private var drawnPeople = 0
    private var nextPartyID = 1
    private var nextAgentID = 1

    init(world: CrowdWorld, settings: SimulationSettings) {
        self.world = world
        totalVisitors = settings.totalVisitors
        maxQueueLength = settings.maxQueueLength
        maxQueueWaitSeconds = settings.maxQueueWaitSeconds
        let weights = [
            (CrowdParameters.social, max(0, settings.socializerWeight)),
            (CrowdParameters.family, max(0, settings.familyWeight)),
            (CrowdParameters.stroller, max(0, settings.strollerWeight)),
            (CrowdParameters.buyer, max(0, settings.buyerWeight))
        ]
        personaWeights = weights.map { (persona: $0.0, weight: $0.1 + 1e-9) }
        arrivalRatePerSecond = settings.arrivalsPer15Min / 900.0 / Self.meanPartySize(personaWeights)

        waitingOutside = Array(repeating: [], count: world.gates.count)
        gateTokens = Array(repeating: CrowdParameters.initialGateTokens, count: world.gates.count)
        browsers = Array(repeating: [], count: world.booths.count)
        queues = Array(repeating: [], count: world.booths.count)
        tableOccupants = Array(repeating: nil, count: world.tables.count)
        arrivalRandom = SeededRandom(seed: settings.randomSeed &* 31 &+ 1)
        traitRandom = SeededRandom(seed: settings.randomSeed &* 31 &+ 2)
        choiceRandom = SeededRandom(seed: settings.randomSeed &* 31 &+ 3)
        spatialHash = CrowdSpatialHash(width: world.width, height: world.height)
    }

    var time: Double { Double(stepCount) / Double(CrowdParameters.stepsPerSecond) }

    var peopleInside: Int { parties.reduce(0) { $0 + $1.people } }

    func step() {
        if parties.isEmpty && drawnPeople >= totalVisitors && waitingOutside.allSatisfy(\.isEmpty) {
            stepCount += 1
            return
        }
        refillGateTokens()
        if drawnPeople < totalVisitors {
            drawArrivals()
        }
        admitWaitingParties()
        for party in parties where time >= party.nextThink {
            party.nextThink = time + CrowdParameters.thinkInterval
            think(party)
        }
        updateQueueHolds()
        moveAgents()
        stepCount += 1
    }

    /// Ends every stop and sends each party to the exit. From here on nobody arrives.
    func startClosing() {
        guard !isClosing else { return }
        isClosing = true
        waitingOutside = waitingOutside.map { _ in [] }
        for party in parties {
            if party.state == .seated {
                standUp(party)
                continue
            }
            if let booth = party.currentBooth { browsers[booth].removeAll { $0 === party } }
            if case .booth(let booth, _) = party.target { queues[booth].removeAll { $0 === party } }
            if case .table(let table) = party.target { tableOccupants[table] = nil }
            party.currentBooth = nil
            party.queuedAt = nil
            party.state = .walking
            pickTarget(party)
        }
    }

    func snapshots() -> [SimulatedVisitor] {
        agents.map { agent in
            SimulatedVisitor(
                id: agent.id,
                position: agent.position,
                state: Self.visitorState(of: agent.party),
                peopleCount: UInt8(agent.weight)
            )
        }
    }

    func copyCounts(into metrics: inout SimulationMetrics) {
        metrics.arrivals = stats.enteredPeople
        metrics.departed = stats.departedPeople
        metrics.peopleInside = peopleInside
        metrics.totalVisits = stats.visits
        metrics.queueBalks = stats.balks
        if stats.departedPeople > 0 {
            metrics.averageStaySeconds = stats.staySeconds / Double(stats.departedPeople)
        }
    }

    private static func visitorState(of party: CrowdParty) -> VisitorState {
        switch party.state {
        case .queueing: return .queueing
        case .visiting: return .browsing
        case .seated: return .seated
        case .walking:
            if case .exit = party.target { return .exiting }
            return .walking
        }
    }

    // MARK: - Arrivals

    private func refillGateTokens() {
        for gate in gateTokens.indices {
            let flow = CrowdParameters.doorFlowPerMetre * world.gateWidths[gate]
            gateTokens[gate] = min(gateTokens[gate] + flow * CrowdParameters.stepSeconds, max(4, 2 * flow))
        }
    }

    private func drawArrivals() {
        guard !isClosing else { return }
        var drawnThisStep = 0
        while nextArrival <= time && drawnThisStep < 50 {
            drawnThisStep += 1
            if drawnPeople < totalVisitors {
                let draw = drawParty(limit: totalVisitors - drawnPeople)
                drawnPeople += draw.people
                let gate = arrivalRandom.randomInt(in: 0...(world.gates.count - 1))
                waitingOutside[gate].append(draw)
            }
            nextArrival += arrivalRandom.nextExponential(rate: arrivalRatePerSecond)
        }
    }

    private func admitWaitingParties() {
        for gate in waitingOutside.indices {
            while let draw = waitingOutside[gate].first, spawn(draw, atGate: gate) {
                waitingOutside[gate].removeFirst()
            }
        }
    }

    private func updateQueueHolds() {
        for party in parties {
            guard party.state == .queueing, case .booth(let booth, _) = party.target else {
                party.isHoldingInQueue = false
                continue
            }
            let rank = max(0, queues[booth].firstIndex { $0 === party } ?? 0)
            let cost = Double(targetField(of: party).costs[world.cell(at: party.leader.position)])
            party.isHoldingInQueue = cost <= queueSpot(booth: booth, rank: rank) + CrowdParameters.queueHoldToleranceM
        }
    }

    // MARK: - Who arrives

    /// `limit` keeps the event at exactly the configured visitor total.
    func drawParty(limit: Int) -> CrowdPartyDraw {
        let persona = pickPersona()
        if persona.isFamily, limit >= 3 {
            let kids = limit >= 4 && traitRandom.nextDouble() < CrowdParameters.twoKidsShare ? 2 : 1
            var carried = 0
            for _ in 0..<kids where carried < 2 && traitRandom.nextDouble() < CrowdParameters.carriedShareOfKids {
                carried += 1
            }
            return CrowdPartyDraw(persona: persona, kind: .family, adults: 2, kids: kids, carried: carried)
        }
        if limit == 1 || traitRandom.nextDouble() < persona.aloneChance {
            return CrowdPartyDraw(persona: persona, kind: .alone, adults: 1, kids: 0, carried: 0)
        }
        let friends = min(limit, traitRandom.nextDouble() < CrowdParameters.pairShare ? 2 : 3)
        return CrowdPartyDraw(persona: persona, kind: .friends, adults: friends, kids: 0, carried: 0)
    }

    private func pickPersona() -> CrowdPersona {
        let weights = personaWeights.map(\.weight)
        return personaWeights[pickIndex(weights: weights, using: &traitRandom)].persona
    }

    func pickIndex(weights: [Double], using random: inout SeededRandom) -> Int {
        var roll = random.nextDouble() * weights.reduce(0, +)
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll <= 0 { return index }
        }
        return weights.count - 1
    }

    private static func meanPartySize(_ weights: [(persona: CrowdPersona, weight: Double)]) -> Double {
        let total = weights.reduce(0) { $0 + $1.weight }
        let friendsMean = 2 * CrowdParameters.pairShare + 3 * (1 - CrowdParameters.pairShare)
        return weights.reduce(0) { sum, entry in
            let size = entry.persona.isFamily
                ? 3 + CrowdParameters.twoKidsShare
                : entry.persona.aloneChance + (1 - entry.persona.aloneChance) * friendsMean
            return sum + entry.weight / total * size
        }
    }

    static func baseSpeed(for kind: CrowdPartyKind) -> Double {
        switch kind {
        case .alone: return CrowdParameters.walkAlone
        case .friends: return CrowdParameters.walkGroup
        case .family: return CrowdParameters.walkWithKids
        }
    }

    // MARK: - Entering the venue

    /// Returns false while the door is at its flow limit or the entrance is crowded, and the party waits outside.
    @discardableResult
    func spawn(_ draw: CrowdPartyDraw, atGate gate: Int) -> Bool {
        let gatePoint = world.gates[gate]
        let checkRadius = CrowdParameters.gateCrowdCheckRadiusM
        var peopleNearGate = 0
        for agent in agents {
            if abs(agent.position.x - gatePoint.x) < checkRadius && abs(agent.position.y - gatePoint.y) < checkRadius {
                peopleNearGate += 1
                if peopleNearGate > CrowdParameters.maxAgentsNearGate { return false }
            }
        }
        guard gateTokens[gate] >= 1 else { return false }
        gateTokens[gate] -= Double(draw.people)

        let speed = min(
            CrowdParameters.speedLimits.upperBound,
            max(
                CrowdParameters.speedLimits.lowerBound,
                Self.baseSpeed(for: draw.kind) + CrowdParameters.speedSpread * traitRandom.nextGaussian()
            )
        )
        let loyaltyJitter = (traitRandom.nextDouble() * 2 - 1) * CrowdParameters.loyaltyRandomSpread
        let loyalty = min(CrowdParameters.maxLoyaltyScore, max(0, draw.persona.loyalty + loyaltyJitter))
        let party = CrowdParty(
            id: nextPartyID,
            draw: draw,
            gate: gate,
            speed: speed,
            loyalty: loyalty,
            time: time,
            nextThink: time + 0.3 + 0.4 * choiceRandom.nextDouble()
        )
        nextPartyID += 1

        party.plan = planBooths(for: draw.persona, gate: gate)
        if party.isGoalDriven && party.plan.isEmpty { party.isGoalDriven = false }
        addMembers(of: draw, to: party, near: gatePoint)
        parties.append(party)
        stats.enteredPeople += draw.people
        pickTarget(party)
        return true
    }

    private func planBooths(for persona: CrowdPersona, gate: Int) -> [Int] {
        let pool = world.booths.indices.filter {
            world.booths[$0].isReachable(fromGate: gate) && !world.booths[$0].isEntertainment
        }
        let stops = traitRandom.randomInt(in: persona.plannedBooths)
        var chosen: [Int] = []

        for _ in 0..<stops {
            let wantsFood = traitRandom.nextDouble() < persona.foodShare
            var candidates = pool.filter { !chosen.contains($0) && world.booths[$0].isFood == wantsFood }
            if candidates.isEmpty { candidates = pool.filter { !chosen.contains($0) } }
            guard !candidates.isEmpty else { break }
            let pulls = candidates.map { world.booths[$0].pull }
            chosen.append(candidates[pickIndex(weights: pulls, using: &choiceRandom)])
        }
        return chosen.sorted { world.booths[$0].gateCosts[gate] < world.booths[$1].gateCosts[gate] }
    }

    private func addMembers(of draw: CrowdPartyDraw, to party: CrowdParty, near gatePoint: SIMD2<Double>) {
        for slot in 0..<draw.walkers {
            let isKid = slot >= draw.adults
            let isCarrying = !isKid && slot < draw.carried
            let radius = isKid
                ? CrowdParameters.kidRadiusM
                : (isCarrying ? CrowdParameters.carryingAdultRadiusM : CrowdParameters.adultRadiusM)
            let weight = isCarrying ? CrowdParameters.carryingAdultPeopleWeight : CrowdParameters.adultPeopleWeight
            let member = CrowdAgent(
                id: nextAgentID,
                party: party,
                slotIndex: slot,
                body: (radius: radius, weight: weight),
                idleOffset: SIMD2(choiceRandom.nextDouble() - 0.5, choiceRandom.nextDouble() - 0.5) * 1.4,
                position: entryPoint(near: gatePoint)
            )
            nextAgentID += 1
            party.members.append(member)
            agents.append(member)
        }
    }

    private func entryPoint(near gatePoint: SIMD2<Double>) -> SIMD2<Double> {
        var point = gatePoint + SIMD2(choiceRandom.nextDouble() - 0.5, choiceRandom.nextDouble() - 0.5) * 1.2
        var attempts = 0
        while world.wallDistance(at: point) < 0.4 && attempts < 30 {
            attempts += 1
            point = gatePoint + SIMD2(choiceRandom.nextDouble() - 0.5, choiceRandom.nextDouble() - 0.5) * 1.6
        }
        return world.nearestFreePoint(to: point)
    }
}
