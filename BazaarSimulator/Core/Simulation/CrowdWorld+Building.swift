import Foundation
import simd

extension CrowdWorld {
    static func resolveEntrances(in layout: Layout) -> [SIMD2<Double>] {
        let markers = layout.markers.filter { $0.kind == .spawn }.map(\.position)
        if !markers.isEmpty { return markers }

        let doors = layout.objects.filter { $0.kind == .door && ($0.doorFlow?.direction.allowsEntry ?? true) }
        if !doors.isEmpty { return doors.map(\.placement.center) }

        return [SIMD2(layout.sizeM.x / 2.0, max(1.0, layout.sizeM.y - 2.0))]
    }

    static func resolveExits(in layout: Layout) -> [SIMD2<Double>] {
        let markers = layout.markers.filter { $0.kind == .exit }.map(\.position)
        if !markers.isEmpty { return markers }

        let doors = layout.objects.filter { $0.kind == .door && ($0.doorFlow?.direction.allowsExit ?? true) }
        if !doors.isEmpty { return doors.map(\.placement.center) }

        return resolveEntrances(in: layout)
    }

    private var activeDoors: [LayoutObject] {
        layout.objects.filter { $0.kind == .door && $0.doorFlow?.direction != .disabled }
    }

    func buildBoothsAndTables(legend: Legend) {
        let foodCategories = Set(legend.entries.filter { $0.type == .fnb }.map(\.id))
        for object in layout.objects where object.kind == .booth || object.kind == .entertainment {
            let isFood = object.categoryID.map(foodCategories.contains) ?? false
            let size = object.placement.sizeM
            booths.append(CrowdBooth(
                id: object.id,
                isFood: isFood,
                isEntertainment: object.kind == .entertainment,
                footprint: CrowdFootprint(object.placement, margin: isFood ? 0 : Self.stockSpill(for: size)),
                pull: min(5, max(1, object.attractiveness)),
                capacity: max(1, Int(max(size.x, size.y) / 0.75))
            ))
        }
        for object in layout.objects where object.kind == .table {
            let size = object.placement.sizeM
            let corners = [SIMD2(-0.25, -0.25), SIMD2(0.25, -0.25), SIMD2(-0.25, 0.25), SIMD2(0.25, 0.25)]
            tables.append(CrowdTable(
                footprint: CrowdFootprint(object.placement),
                seats: corners.map { object.placement.center + $0 * size }
            ))
        }
        for object in layout.objects where object.kind == .seating {
            tables.append(contentsOf: Self.seatGroups(in: object))
        }
    }

    /// A seating block splits along each row into groups of up to four chairs, one party to a group.
    static func seatGroups(in block: LayoutObject) -> [CrowdTable] {
        let chairs = FurnitureModels.chairs(of: block)
        let perRow = FurnitureModels.seatsAlong(block.placement.sizeM.x)
        var groups: [CrowdTable] = []
        for rowStart in stride(from: 0, to: chairs.count, by: perRow) {
            let row = Array(chairs[rowStart..<min(chairs.count, rowStart + perRow)])
            for groupStart in stride(from: 0, to: row.count, by: CrowdParameters.seatsPerGroup) {
                let group = row[groupStart..<min(row.count, groupStart + CrowdParameters.seatsPerGroup)]
                let centers = group.map(\.center)
                let span = Double(centers.count - 1) * FurnitureModels.seatPitchM
                let footprint = Placement(
                    center: centers.reduce(.zero, +) / Double(centers.count),
                    sizeM: SIMD2(span + FurnitureModels.chairSizeM.x, FurnitureModels.chairSizeM.y),
                    rotationRadians: block.placement.rotationRadians
                )
                groups.append(CrowdTable(footprint: CrowdFootprint(footprint), seats: centers))
            }
        }
        return groups
    }

    /// The margin that grows a small goods booth until its area reaches `stockArea`.
    static func stockSpill(for size: SIMD2<Double>) -> Double {
        let area = size.x * size.y
        guard area < CrowdParameters.stockArea else { return 0 }
        let perimeter = size.x + size.y
        let missing = CrowdParameters.stockArea - area
        return min(1.0, (-2 * perimeter + (4 * perimeter * perimeter + 16 * missing).squareRoot()) / 8)
    }

    func buildFloor() {
        for cell in 0..<cellCount {
            walls.floor[cell] = isOnFloorPlan(cellCenter(cell))
        }
        // The half-cell tolerance stops a wall thinner than a cell from slipping between cell centres.
        let attractionKinds: Set<LayoutObjectKind> = [.booth, .entertainment]
        for object in layout.objects where object.kind.blocksWalking && !attractionKinds.contains(object.kind) {
            setFloor(false, inside: object.placement, tolerance: Self.cellSize / 2)
        }
        for booth in booths {
            let halfSize = booth.footprint.halfSize
            setFloor(
                false,
                inside: Placement(
                    center: booth.footprint.center,
                    sizeM: halfSize * 2,
                    rotationRadians: boothRotation(id: booth.id)
                ),
                tolerance: Self.cellSize / 2
            )
        }
        for door in activeDoors {
            setFloor(true, inside: carvedPlacement(of: door), tolerance: 0.25)
        }
    }

    private func boothRotation(id: UUID) -> Double {
        layout.objects.first { $0.id == id }?.placement.rotationRadians ?? 0
    }

    private func isOnFloorPlan(_ point: SIMD2<Double>) -> Bool {
        guard layout.hall.count >= 3 || layout.lobby.count >= 3 else {
            return point.x >= 0.5 && point.x <= layout.sizeM.x - 0.5
                && point.y >= 0.5 && point.y <= layout.sizeM.y - 0.5
        }
        return LayoutGeometry.polygonContains(layout.hall, point: point)
            || LayoutGeometry.polygonContains(layout.lobby, point: point)
    }

    private func setFloor(_ value: Bool, inside placement: Placement, tolerance: Double) {
        let reach = simd_length(placement.sizeM) / 2 + tolerance + Self.cellSize
        for cell in cellsInBox(around: placement.center, reach: reach)
        where LayoutGeometry.contains(placement, point: cellCenter(cell), tolerance: tolerance) {
            walls.floor[cell] = value
        }
    }

    private func carvedPlacement(of door: LayoutObject) -> Placement {
        var carved = door.placement
        carved.sizeM.x = max(carved.sizeM.x, 1.4)
        carved.sizeM.y = max(carved.sizeM.y, 1.6)
        return carved
    }

    func buildWallDistances() {
        let toObstacle = chamferDistances(toCellsWhereFloorIs: false, cap: 11)
        let toFloor = chamferDistances(toCellsWhereFloorIs: true, cap: 6)
        for cell in 0..<cellCount {
            let cells = walls.floor[cell] ? toObstacle[cell] : toFloor[cell]
            let metres = max(0, cells * Float(Self.cellSize) - Float(Self.cellSize) / 2)
            walls.wallDistances[cell] = walls.floor[cell] ? metres : -(metres + 0.001)
        }
    }

    /// Distance in cells to the nearest target cell, using a forward and a backward sweep.
    private func chamferDistances(toCellsWhereFloorIs target: Bool, cap: Float) -> [Float] {
        var distances = walls.floor.map { $0 == target ? Float(0) : cap }
        let diagonal: Float = 1.4142135
        for cell in 0..<cellCount {
            let col = cell % cols
            let row = cell / cols
            var best = distances[cell]
            if col > 0 { best = min(best, distances[cell - 1] + 1) }
            if row > 0 {
                best = min(best, distances[cell - cols] + 1)
                if col > 0 { best = min(best, distances[cell - cols - 1] + diagonal) }
                if col < cols - 1 { best = min(best, distances[cell - cols + 1] + diagonal) }
            }
            distances[cell] = best
        }
        for cell in (0..<cellCount).reversed() {
            let col = cell % cols
            let row = cell / cols
            var best = distances[cell]
            if col < cols - 1 { best = min(best, distances[cell + 1] + 1) }
            if row < rows - 1 {
                best = min(best, distances[cell + cols] + 1)
                if col < cols - 1 { best = min(best, distances[cell + cols + 1] + diagonal) }
                if col > 0 { best = min(best, distances[cell + cols - 1] + diagonal) }
            }
            distances[cell] = best
        }
        return distances
    }

    func buildOneWayDoors() {
        for door in activeDoors {
            guard let direction = door.doorFlow?.direction, direction == .entrance || direction == .exit else {
                continue
            }
            // A door that doubles as the only entrance or exit has to stay usable for that route.
            let center = door.placement.center
            let isExitOnly = direction == .exit && !Self.resolveEntrances(in: layout).contains(center)
            let isEntranceOnly = direction == .entrance && !Self.resolveExits(in: layout).contains(center)
            let inward = inwardNormal(of: door)

            for cell in oneWayCells(of: door) {
                if isExitOnly { inboundBlocked[cell] = true }
                if isEntranceOnly { outboundBlocked[cell] = true }
                if let inward, isExitOnly || isEntranceOnly {
                    doorRules[cell] = CrowdDoorRule(inward: inward, forbidsWalkingIn: isExitOnly)
                }
            }
        }
    }

    /// The full width of the carved opening, but only as deep as the door itself.
    private func oneWayCells(of door: LayoutObject) -> [Int] {
        let carved = carvedPlacement(of: door).sizeM
        let size = door.placement.sizeM
        var band = door.placement
        band.sizeM = size.x >= size.y
            ? SIMD2(carved.x + 0.5, size.y + 0.25)
            : SIMD2(size.x + 0.25, carved.y + 0.5)
        let reach = simd_length(band.sizeM) / 2 + Self.cellSize
        return cellsInBox(around: band.center, reach: reach).filter {
            walls.floor[$0] && LayoutGeometry.contains(band, point: cellCenter($0))
        }
    }

    /// Points across the door toward the inside of the venue.
    private func inwardNormal(of door: LayoutObject) -> SIMD2<Double>? {
        let rotation = door.placement.rotationRadians
        let isWide = door.placement.sizeM.x >= door.placement.sizeM.y
        let normal = isWide ? SIMD2(-sin(rotation), cos(rotation)) : SIMD2(cos(rotation), sin(rotation))
        let inside = door.doorFlow?.connection == .lobbyToOutside ? layout.lobby : layout.hall
        let center = door.placement.center
        if LayoutGeometry.polygonContains(inside, point: center + normal) { return normal }
        if LayoutGeometry.polygonContains(inside, point: center - normal) { return -normal }
        return nil
    }

    func buildGateWidths() {
        let entryDoors = activeDoors.filter { $0.doorFlow?.direction.allowsEntry ?? true }
        gateWidths = gates.map { gate in
            let nearest = entryDoors.min {
                simd_distance($0.placement.center, gate) < simd_distance($1.placement.center, gate)
            }
            // Assumption: a venue with no entry door admits people like a 2 m doorway.
            return max(0.3, nearest.map { max($0.placement.sizeM.x, $0.placement.sizeM.y) } ?? 2.0)
        }
    }

    func buildCornerSlowdown() {
        let radius = CrowdParameters.cornerRadius
        for corner in innerHallCorners() {
            for cell in cellsInBox(around: corner, reach: radius) where walls.floor[cell] {
                let distance = simd_distance(cellCenter(cell), corner)
                guard distance < radius else { continue }
                cornerWeights[cell] = max(cornerWeights[cell], Float(1 - distance / radius))
            }
        }
    }

    private func innerHallCorners() -> [SIMD2<Double>] {
        let hall = layout.hall
        guard hall.count >= 3 else { return [] }
        let count = hall.count
        let area = (0..<count).reduce(0.0) { sum, index in
            let next = hall[(index + 1) % count]
            return sum + hall[index].x * next.y - next.x * hall[index].y
        }
        let winding = area > 0 ? 1.0 : -1.0

        return (0..<count).compactMap { index in
            let incoming = hall[index] - hall[(index + count - 1) % count]
            let outgoing = hall[(index + 1) % count] - hall[index]
            let lengths = simd_length(incoming) * simd_length(outgoing)
            guard simd_length(incoming) >= 1.5, simd_length(outgoing) >= 1.5 else { return nil }
            let cross = incoming.x * outgoing.y - incoming.y * outgoing.x
            let isNearlySquare = abs(simd_dot(incoming, outgoing) / lengths) < 0.35
            return cross * winding < 0 && isNearlySquare ? hall[index] : nil
        }
    }

    func measureRoutesFromGates() {
        let gateFields = gates.indices.map { flowField(to: .gate($0)) }
        for index in booths.indices {
            let ring = ringCells(around: booths[index].footprint, from: 0, to: 0.8)
            booths[index].gateCosts = gateFields.map { field in
                ring.map { field.costs[$0] }.min() ?? .infinity
            }
        }
        for index in tables.indices {
            let ring = ringCells(around: tables[index].footprint, from: 0, to: 0.6)
            tables[index].isReachable = gateFields.contains { field in
                (ring.map { field.costs[$0] }.min() ?? .infinity) < Self.reachableCostLimit
            }
        }
    }
}
