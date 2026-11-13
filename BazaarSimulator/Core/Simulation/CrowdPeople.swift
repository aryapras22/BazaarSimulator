import Foundation
import simd

nonisolated enum CrowdPartyKind {
    case alone
    case friends
    case family
}

nonisolated enum CrowdPartyState {
    case walking
    case queueing
    case visiting
    case seated
}

nonisolated enum CrowdVisitReason {
    case planned
    case detour
    case stopover
    case passingThrough
}

nonisolated enum CrowdTarget {
    case booth(Int, CrowdVisitReason)
    case table(Int)
    case exit
}

nonisolated struct CrowdPartyDraw {
    let persona: CrowdPersona
    let kind: CrowdPartyKind
    let adults: Int
    let kids: Int
    let carried: Int

    var people: Int { adults + kids }
    var walkers: Int { people - carried }
}

nonisolated struct CrowdStats {
    var enteredPeople = 0
    var departedPeople = 0
    var visits = 0
    var balks = 0
    var staySeconds = 0.0
}

/// One walking body on the floor. An adult carrying a child counts as two people.
nonisolated final class CrowdAgent {
    let id: Int
    unowned let party: CrowdParty
    let slotIndex: Int
    let radius: Double
    let weight: Double
    let idleOffset: SIMD2<Double>
    var position: SIMD2<Double>
    var velocity = SIMD2<Double>.zero
    var isSeated = false
    var positionBeforeSeat = SIMD2<Double>.zero
    var bodyIndex = 0

    init(
        id: Int,
        party: CrowdParty,
        slotIndex: Int,
        body: (radius: Double, weight: Double),
        idleOffset: SIMD2<Double>,
        position: SIMD2<Double>
    ) {
        self.id = id
        self.party = party
        self.slotIndex = slotIndex
        radius = body.radius
        weight = body.weight
        self.idleOffset = idleOffset
        self.position = position
    }
}

/// One visitor, friends or a family, moving and deciding together. The first member leads.
nonisolated final class CrowdParty {
    let id: Int
    let persona: CrowdPersona
    let gate: Int
    let people: Int
    let walkers: Int
    let speed: Double
    let enteredAt: Double
    var isGoalDriven: Bool
    var loyalty: Double
    var members: [CrowdAgent] = []
    var plan: [Int] = []
    var visited = Set<Int>()
    var state = CrowdPartyState.walking
    var target = CrowdTarget.exit
    var detours = 0
    var stopoversLeft: Int
    var hasWalkedTheHall = false
    var willSit = false
    var eatSeconds = 0.0
    var heading = Double.pi
    var nextThink: Double
    var lastCost = Double.infinity
    var lastProgress: Double
    var endTime = 0.0
    var currentBooth: Int?
    var currentReason = CrowdVisitReason.planned
    var isHoldingInQueue = false
    var queuedAt: Double?
    var seat: Int?
    var heldForward: SIMD2<Double>?

    init(id: Int, draw: CrowdPartyDraw, gate: Int, speed: Double, loyalty: Double, time: Double, nextThink: Double) {
        self.id = id
        persona = draw.persona
        self.gate = gate
        people = draw.people
        walkers = draw.walkers
        self.speed = speed
        self.loyalty = loyalty
        enteredAt = time
        isGoalDriven = draw.persona.isGoalDriven
        stopoversLeft = draw.persona.stopovers
        self.nextThink = nextThink
        lastProgress = time
    }

    var leader: CrowdAgent { members[0] }

    func restartProgress(at time: Double) {
        lastCost = .infinity
        lastProgress = time
    }
}

/// Finds nearby agents without comparing every pair.
nonisolated struct CrowdSpatialHash {
    static let binSize = CrowdParameters.spatialHashBinSize

    private let cols: Int
    private let rows: Int
    private var heads: [Int32]
    private var nexts: [Int32] = []
    private var occupiedBins: [Int] = []

    init(width: Double, height: Double) {
        cols = max(1, Int(ceil(width / Self.binSize)))
        rows = max(1, Int(ceil(height / Self.binSize)))
        heads = Array(repeating: -1, count: cols * rows)
    }

    private func binCoordinates(of point: SIMD2<Double>) -> (col: Int, row: Int) {
        (min(cols - 1, max(0, Int(point.x / Self.binSize))), min(rows - 1, max(0, Int(point.y / Self.binSize))))
    }

    mutating func rebuild(with bodies: [CrowdBody]) {
        for bin in occupiedBins { heads[bin] = -1 }
        occupiedBins.removeAll(keepingCapacity: true)
        if nexts.count < bodies.count {
            nexts = Array(repeating: -1, count: bodies.count)
        }

        for (index, body) in bodies.enumerated() {
            let (col, row) = binCoordinates(of: body.position)
            let bin = row * cols + col
            if heads[bin] < 0 { occupiedBins.append(bin) }
            nexts[index] = heads[bin]
            heads[bin] = Int32(index)
        }
    }

    /// Calls `body` with every agent index in the 3 by 3 bins around `point`.
    @inline(__always)
    func forEachNearby(_ point: SIMD2<Double>, body: (Int) -> Void) {
        let (col, row) = binCoordinates(of: point)
        for nearRow in max(0, row - 1)...min(rows - 1, row + 1) {
            for nearCol in max(0, col - 1)...min(cols - 1, col + 1) {
                var index = heads[nearRow * cols + nearCol]
                while index >= 0 {
                    body(Int(index))
                    index = nexts[Int(index)]
                }
            }
        }
    }
}
