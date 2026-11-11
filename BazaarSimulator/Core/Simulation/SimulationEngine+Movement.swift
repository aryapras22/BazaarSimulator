import Foundation
import simd

// MARK: - Visitor Movement & Booth Visits

extension SimulationEngine {
    func updateVisitors(dt: Double) {
        let snapshotPositions = visitors.map { ($0.id, $0.position) }
        var index = 0

        while index < visitors.count {
            var visitor = visitors[index]
            visitor.timeInState += dt
            visitor.totalStaySeconds += dt

            switch visitor.state {
            case .walking:
                updateWalkingVisitor(&visitor, dt: dt, others: snapshotPositions)
            case .queueing:
                updateQueueingVisitor(&visitor)
            case .browsing:
                updateBrowsingVisitor(&visitor)
            case .exiting:
                if updateExitingVisitor(&visitor, dt: dt, others: snapshotPositions) {
                    metrics.departed += visitor.partySize
                    stayDurations.append(visitor.totalStaySeconds)
                    visitors.remove(at: index)
                    continue
                }
            }

            visitors[index] = visitor
            index += 1
        }
    }

    func updateWalkingVisitor(
        _ visitor: inout SimulatedVisitor,
        dt: Double,
        others: [(Int, SIMD2<Double>)]
    ) {
        moveVisitor(&visitor, dt: dt, others: others)
        guard let boothID = visitor.targetBoothID, let booth = boothByID[boothID] else {
            assignNextDestination(&visitor)
            return
        }
        let approach = navGrid.boothApproachPoint(for: booth)
        if simd_distance(visitor.position, approach) < 0.9 {
            handleArrivalAtBooth(&visitor, booth: booth)
        }
    }

    func handleArrivalAtBooth(_ visitor: inout SimulatedVisitor, booth: LayoutObject) {
        let queue = boothQueues[booth.id] ?? []
        if queue.count >= settings.maxQueueLength {
            metrics.queueBalks += 1
            visitor.visitedBoothIDs.append(booth.id)
            visitor.targetBoothID = nil
            assignNextDestination(&visitor)
            return
        }
        boothQueues[booth.id, default: []].append(visitor.id)
        visitor.state = .queueing
        visitor.timeInState = 0
    }

    func updateQueueingVisitor(_ visitor: inout SimulatedVisitor) {
        guard let boothID = visitor.targetBoothID else {
            assignNextDestination(&visitor)
            return
        }
        let queue = boothQueues[boothID] ?? []
        let serving = boothServingCount[boothID] ?? 0
        let capacity = boothCapacity(for: boothID)

        if queue.first == visitor.id && serving < capacity {
            boothQueues[boothID]?.removeFirst()
            boothServingCount[boothID] = serving + 1
            if !visitor.visitedBoothIDs.contains(boothID) {
                visitor.visitedBoothIDs.append(boothID)
            }
            visitor.state = .browsing
            visitor.timeInState = 0
            visitor.stateDuration = rng.randomDouble(in: 18.0...45.0)
            metrics.totalVisits += 1
        } else if visitor.timeInState >= settings.maxQueueWaitSeconds {
            boothQueues[boothID]?.removeAll { $0 == visitor.id }
            visitor.visitedBoothIDs.append(boothID)
            visitor.targetBoothID = nil
            assignNextDestination(&visitor)
        }
    }

    func updateBrowsingVisitor(_ visitor: inout SimulatedVisitor) {
        guard visitor.timeInState >= visitor.stateDuration else { return }
        if let boothID = visitor.targetBoothID {
            boothServingCount[boothID] = max(0, (boothServingCount[boothID] ?? 1) - 1)
        }
        visitor.targetBoothID = nil
        assignNextDestination(&visitor)
    }

    func updateExitingVisitor(
        _ visitor: inout SimulatedVisitor,
        dt: Double,
        others: [(Int, SIMD2<Double>)]
    ) -> Bool {
        moveVisitor(&visitor, dt: dt, others: others)
        let nearestExitDistance = navGrid.exitPoints
            .map { simd_distance(visitor.position, $0) }
            .min() ?? 0.0
        return nearestExitDistance < 1.1 || visitor.path.isEmpty
    }

    func assignNextDestination(_ visitor: inout SimulatedVisitor) {
        let visited = Set(visitor.visitedBoothIDs)
        let remainingBooths = booths.filter { !visited.contains($0.id) }

        if visitor.visitedBoothIDs.count >= visitor.plannedStops || remainingBooths.isEmpty {
            sendVisitorToExit(&visitor)
            return
        }

        let sortedByDistance = remainingBooths.sorted {
            simd_distance(visitor.position, $0.placement.center) < simd_distance(visitor.position, $1.placement.center)
        }
        let topCount = min(sortedByDistance.count, 5)
        let chosenBooth = sortedByDistance[rng.randomInt(in: 0...(topCount - 1))]
        let targetPoint = navGrid.boothApproachPoint(for: chosenBooth)
        let path = navGrid.findPath(from: visitor.position, to: targetPoint)
        guard !path.isEmpty else {
            visitor.visitedBoothIDs.append(chosenBooth.id)
            assignNextDestination(&visitor)
            return
        }

        visitor.targetBoothID = chosenBooth.id
        visitor.state = .walking
        visitor.timeInState = 0
        visitor.path = path
    }

    func sendVisitorToExit(_ visitor: inout SimulatedVisitor) {
        visitor.targetBoothID = nil
        visitor.state = .exiting
        visitor.timeInState = 0

        let nearestExit = navGrid.exitPoints.min {
            simd_distance(visitor.position, $0) < simd_distance(visitor.position, $1)
        } ?? SIMD2<Double>(layout.sizeM.x / 2.0, layout.sizeM.y / 2.0)

        visitor.path = navGrid.findPath(from: visitor.position, to: nearestExit)
    }

    func moveVisitor(
        _ visitor: inout SimulatedVisitor,
        dt: Double,
        others: [(Int, SIMD2<Double>)]
    ) {
        while let firstWaypoint = visitor.path.first, simd_distance(visitor.position, firstWaypoint) < 0.25 {
            visitor.path.removeFirst()
        }
        guard let target = visitor.path.first else { return }
        let toTarget = target - visitor.position
        let dist = simd_length(toTarget)
        guard dist > 0.001 else { return }

        var moveDir = toTarget / dist
        let combined = moveDir + crowdRepulsion(for: visitor, others: others) * 0.65
        if simd_length(combined) > 0.001 {
            moveDir = simd_normalize(combined)
        }

        let stepDistance = min(dist, visitor.speed * dt)
        let nextPoint = visitor.position + moveDir * stepDistance

        if navGrid.isWalkable(nextPoint) {
            visitor.position = nextPoint
            visitor.heading = atan2(moveDir.y, moveDir.x)
        } else {
            let slideX = SIMD2<Double>(visitor.position.x + moveDir.x * stepDistance, visitor.position.y)
            let slideY = SIMD2<Double>(visitor.position.x, visitor.position.y + moveDir.y * stepDistance)
            if navGrid.isWalkable(slideX) {
                visitor.position = slideX
            } else if navGrid.isWalkable(slideY) {
                visitor.position = slideY
            }
        }
    }

    func crowdRepulsion(
        for visitor: SimulatedVisitor,
        others: [(Int, SIMD2<Double>)]
    ) -> SIMD2<Double> {
        var push = SIMD2<Double>.zero
        let personalSpace = 0.65
        for (otherID, otherPos) in others where otherID != visitor.id {
            let offset = visitor.position - otherPos
            let distance = simd_length(offset)
            if distance > 0.01 && distance < personalSpace {
                push += offset * ((personalSpace - distance) / distance)
            }
        }
        return push
    }

    func boothCapacity(for boothID: UUID) -> Int {
        guard let booth = boothByID[boothID] else { return 2 }
        return max(1, Int(max(booth.placement.sizeM.x, booth.placement.sizeM.y) / 0.8))
    }

    func updateDensityCells() {
        let bucketSize = 1.0
        let bucketCols = max(1, Int(ceil(layout.sizeM.x / bucketSize)))
        let bucketRows = max(1, Int(ceil(layout.sizeM.y / bucketSize)))
        let instantByCell = computeKernelDensity(
            bucketSize: bucketSize,
            bucketCols: bucketCols,
            bucketRows: bucketRows
        )

        let allKeys = Set(smoothedDensityByCell.keys).union(instantByCell.keys).sorted()
        var activeCells: [DensityCell] = []

        for key in allKeys {
            let instant = instantByCell[key] ?? 0.0
            let smoothed = (smoothedDensityByCell[key] ?? 0.0) * 0.72 + instant * 0.28
            if smoothed < 0.004 {
                smoothedDensityByCell.removeValue(forKey: key)
                continue
            }
            smoothedDensityByCell[key] = smoothed
            let col = key % bucketCols
            let row = key / bucketCols
            let center = SIMD2<Double>((Double(col) + 0.5) * bucketSize, (Double(row) + 0.5) * bucketSize)
            let cell = DensityCell(id: key, center: center, peoplePerSquareMetre: smoothed)
            activeCells.append(cell)

            if (peakCellsByID[key]?.peoplePerSquareMetre ?? 0) < smoothed {
                peakCellsByID[key] = cell
            }
        }

        densityCells = activeCells
        let totalDensity = densityCells.reduce(0.0) { $0 + $1.peoplePerSquareMetre }
        metrics.meanDensity = densityCells.isEmpty ? 0 : totalDensity / Double(densityCells.count)
        metrics.peakDensity = max(metrics.peakDensity, densityCells.map(\.peoplePerSquareMetre).max() ?? 0)
    }

    private func computeKernelDensity(
        bucketSize: Double,
        bucketCols: Int,
        bucketRows: Int
    ) -> [Int: Double] {
        // This spread keeps one standing person at about 0.073 /m², inside grade A's limit of 0.08.
        let twoSigmaSq = 2.0 * 1.5 * 1.5
        var kernel: [(offset: SIMD2<Int>, weight: Double)] = []
        for dRow in -3...3 {
            for dCol in -3...3 {
                kernel.append((SIMD2(dCol, dRow), exp(-Double(dCol * dCol + dRow * dRow) / twoSigmaSq)))
            }
        }
        let kernelTotal = kernel.reduce(0.0) { $0 + $1.weight }
        var instantByCell: [Int: Double] = [:]

        for visitor in visitors {
            let col = Int(visitor.position.x / bucketSize)
            let row = Int(visitor.position.y / bucketSize)
            let people = Double(visitor.partySize)

            for cell in kernel {
                let nCol = col + cell.offset.x
                let nRow = row + cell.offset.y
                guard nCol >= 0, nRow >= 0, nCol < bucketCols, nRow < bucketRows else { continue }
                instantByCell[nRow * bucketCols + nCol, default: 0.0] += people * cell.weight / kernelTotal
            }
        }
        return instantByCell
    }
}
