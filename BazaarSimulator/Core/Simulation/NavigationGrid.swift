import Foundation
import simd

/// The layout as a grid of walkable cells, built once per run.
/// Hall and lobby floor are walkable, solid objects are not, and doors cut through walls.
struct NavigationGrid {
    static let cellSizeM = 0.5

    struct Door {
        let label: String
        let center: SIMD2<Double>
        let flow: DoorFlow?
        let cells: [Int]
    }

    let origin: SIMD2<Double>
    let columns: Int
    let rows: Int
    private(set) var walkable: [Bool]
    /// For each cell, the index in `doors` of the door it belongs to, or -1.
    private(set) var doorIndex: [Int16]
    private(set) var doors: [Door] = []

    var cellCount: Int { columns * rows }

    /// The area the grid covers, in layout meters.
    var plan: PlanFrame {
        PlanFrame(origin: origin, size: SIMD2(Double(columns), Double(rows)) * Self.cellSizeM)
    }

    var walkableMask: WalkableMask {
        WalkableMask(origin: origin, cellSizeM: Self.cellSizeM, columns: columns, rows: rows, cells: walkable)
    }

    init(layout: Layout) {
        let floor = layout.hall + layout.lobby
        let box = floor.isEmpty
            ? BoundingBox(minX: 0, maxX: layout.sizeM.x, minY: 0, maxY: layout.sizeM.y)
            : LayoutGeometry.bounds(of: floor)
        origin = SIMD2(box.minX - 1, box.minY - 1)
        columns = max(Int(((box.maxX - box.minX + 2) / Self.cellSizeM).rounded(.up)), 1)
        rows = max(Int(((box.maxY - box.minY + 2) / Self.cellSizeM).rounded(.up)), 1)
        walkable = Array(repeating: false, count: columns * rows)
        doorIndex = Array(repeating: -1, count: columns * rows)

        for index in 0..<walkable.count {
            let point = center(of: index)
            walkable[index] = LayoutGeometry.polygonContains(layout.hall, point: point)
                || LayoutGeometry.polygonContains(layout.lobby, point: point)
        }
        for object in layout.objects where object.kind.blocksWalking {
            // A thin wall can pass between cell centers, so thin objects block every cell they touch.
            let isThin = min(object.placement.sizeM.x, object.placement.sizeM.y) < Self.cellSizeM * 1.5
            for index in cells(in: object.placement, padding: 0, touching: isThin) {
                walkable[index] = false
            }
        }
        for object in layout.objects where object.kind == .door && object.doorFlow?.direction != .disabled {
            let cells = cells(in: object.placement, padding: Self.cellSizeM / 2, usesBoundsOnly: true)
            let index = Int16(doors.count)
            for cell in cells {
                walkable[cell] = true
                doorIndex[cell] = index
            }
            doors.append(Door(
                label: object.label, center: object.placement.center, flow: object.doorFlow, cells: cells
            ))
        }
    }

    // MARK: Cells and points

    func center(of index: Int) -> SIMD2<Double> {
        SIMD2(
            origin.x + (Double(index % columns) + 0.5) * Self.cellSizeM,
            origin.y + (Double(index / columns) + 0.5) * Self.cellSizeM
        )
    }

    func cellIndex(for point: SIMD2<Double>) -> Int? {
        let column = Int(((point.x - origin.x) / Self.cellSizeM).rounded(.down))
        let row = Int(((point.y - origin.y) / Self.cellSizeM).rounded(.down))
        guard column >= 0, column < columns, row >= 0, row < rows else { return nil }
        return row * columns + column
    }

    /// The closest walkable cell to `point`, searching outward up to `radiusM`.
    func nearestWalkableCell(to point: SIMD2<Double>, radiusM: Double = 4) -> Int? {
        guard let start = cellIndex(for: point) else { return nil }
        if walkable[start] { return start }
        let reach = Int((radiusM / Self.cellSizeM).rounded(.up))
        var best: (index: Int, distance: Double)?
        let startColumn = start % columns
        let startRow = start / columns
        for row in max(startRow - reach, 0)...min(startRow + reach, rows - 1) {
            for column in max(startColumn - reach, 0)...min(startColumn + reach, columns - 1) {
                let index = row * columns + column
                guard walkable[index] else { continue }
                let distance = simd_distance(center(of: index), point)
                if best == nil || distance < best!.distance {
                    best = (index, distance)
                }
            }
        }
        return best?.index
    }

    /// Walkable cells in front of a booth: its open sides, or a ring around it when none is set.
    func accessCells(of object: LayoutObject, depthM: Double = 1) -> [Int] {
        var result: [Int] = []
        for side in OpenSides.ordered where object.openSides.contains(side) {
            let strip = LayoutGeometry.stripPlacement(for: side, of: object.placement, depthM: depthM)
            result += cells(in: strip, padding: 0).filter { walkable[$0] }
        }
        if result.isEmpty {
            let placement = object.placement
            let ring = Placement(
                center: placement.center,
                sizeM: placement.sizeM + SIMD2(repeating: depthM * 2),
                rotationRadians: placement.rotationRadians
            )
            result = cells(in: ring, padding: 0).filter { walkable[$0] }
        }
        return result
    }

    // MARK: Distances

    /// Steps to the nearest source over walkable cells, or `Int32.max` where a source cannot be reached.
    func distanceField(from sources: [Int]) -> [Int32] {
        var field = Array(repeating: Int32.max, count: cellCount)
        var queue: [Int] = []
        queue.reserveCapacity(cellCount)
        for source in sources where walkable[source] && field[source] == Int32.max {
            field[source] = 0
            queue.append(source)
        }
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            let next = field[current] + 1
            let column = current % columns
            if column > 0 { relax(current - 1, next, &field, &queue) }
            if column < columns - 1 { relax(current + 1, next, &field, &queue) }
            if current >= columns { relax(current - columns, next, &field, &queue) }
            if current + columns < cellCount { relax(current + columns, next, &field, &queue) }
        }
        return field
    }

    private func relax(_ cell: Int, _ distance: Int32, _ field: inout [Int32], _ queue: inout [Int]) {
        guard walkable[cell], field[cell] == Int32.max else { return }
        field[cell] = distance
        queue.append(cell)
    }

    /// The neighbor of `cell` (including diagonals) that is closest to the target, or nil if none is closer.
    func nextCell(from cell: Int, in field: [Int32]) -> Int? {
        let column = cell % columns
        let row = cell / columns
        var best: Int?
        var bestDistance = field[cell]
        for rowStep in -1...1 {
            for columnStep in -1...1 where rowStep != 0 || columnStep != 0 {
                let neighborColumn = column + columnStep
                let neighborRow = row + rowStep
                guard neighborColumn >= 0, neighborColumn < columns, neighborRow >= 0, neighborRow < rows else {
                    continue
                }
                let neighbor = neighborRow * columns + neighborColumn
                guard walkable[neighbor], field[neighbor] < bestDistance else { continue }
                if rowStep != 0, columnStep != 0 {
                    // No cutting corners through solid cells.
                    guard walkable[row * columns + neighborColumn], walkable[neighborRow * columns + column] else {
                        continue
                    }
                }
                best = neighbor
                bestDistance = field[neighbor]
            }
        }
        return best
    }

    // MARK: Rasterizing

    private func cells(
        in placement: Placement,
        padding: Double,
        usesBoundsOnly: Bool = false,
        touching: Bool = false
    ) -> [Int] {
        let box = LayoutGeometry.bounds(of: placement)
        let minColumn = max(Int(((box.minX - padding - origin.x) / Self.cellSizeM).rounded(.down)), 0)
        let maxColumn = min(Int(((box.maxX + padding - origin.x) / Self.cellSizeM).rounded(.down)), columns - 1)
        let minRow = max(Int(((box.minY - padding - origin.y) / Self.cellSizeM).rounded(.down)), 0)
        let maxRow = min(Int(((box.maxY + padding - origin.y) / Self.cellSizeM).rounded(.down)), rows - 1)
        guard minColumn <= maxColumn, minRow <= maxRow else { return [] }

        var result: [Int] = []
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                let index = row * columns + column
                let point = center(of: index)
                let isInside: Bool
                if usesBoundsOnly {
                    isInside = point.x >= box.minX - padding && point.x <= box.maxX + padding
                        && point.y >= box.minY - padding && point.y <= box.maxY + padding
                } else if touching {
                    let cell = Placement(center: point, sizeM: SIMD2(repeating: Self.cellSizeM))
                    isInside = LayoutGeometry.intersects(placement, cell)
                } else {
                    isInside = LayoutGeometry.contains(placement, point: point)
                }
                if isInside { result.append(index) }
            }
        }
        return result
    }
}
