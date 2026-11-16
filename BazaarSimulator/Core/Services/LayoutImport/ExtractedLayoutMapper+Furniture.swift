import Foundation
import simd

extension ExtractedLayoutMapper {
    /// Standard tables and seating blocks for the tables and chairs found on a plan. A detected box only says where a
    /// piece stands: its model and angle come from the chairs around it, and its size and seats from the model.
    /// Chairs that belong to no table become seating blocks, so none is dropped.
    static func furniture(from items: [DetectedItem], frame: (DetectedItem) -> Placement) -> [LayoutObject] {
        let objects = items.filter { $0.cls == "object" }
        let groups = objects.filter { $0.kind == "chair_group" }
        let chairs = objects.filter { $0.kind == "chair" }
        var claimed = Set<Int>()
        var result: [LayoutObject] = []

        for table in objects where table.kind == "table" {
            let group = smallestGroup(holding: centre(of: table.box), among: groups)
            let mine = chairs.indices.filter { index in
                !claimed.contains(index) && group.map { contains($0.box, centre(of: chairs[index].box)) } == true
            }
            claimed.formUnion(mine)
            let fit = FurnitureFit.best(
                at: frame(table).center,
                chairCentres: mine.map { frame(chairs[$0]).center }
            )
            result.append(standardTable(fit, number: result.count + 1))
        }

        var blocks: [Int: [Placement]] = [:]
        var singles: [Placement] = []
        for index in chairs.indices where !claimed.contains(index) {
            let placement = frame(chairs[index])
            if let group = smallestGroup(holding: centre(of: chairs[index].box), among: groups),
               let groupIndex = groups.firstIndex(of: group) {
                blocks[groupIndex, default: []].append(placement)
            } else {
                singles.append(placement)
            }
        }
        let seatingGroups = blocks.keys.sorted().compactMap { blocks[$0] } + singles.map { [$0] }
        for chairsInBlock in seatingGroups {
            result.append(seatingBlock(around: chairsInBlock, number: result.count + 1))
        }
        return result
    }

    private static func standardTable(_ fit: FurnitureFit, number: Int) -> LayoutObject {
        LayoutObject(
            kind: .table,
            label: "Table \(number)",
            placement: Placement(
                center: fit.centre,
                sizeM: fit.model.sizeM,
                rotationRadians: Double(fit.angleDegrees) * .pi / 180
            ),
            reviewState: .detected,
            catalogID: fit.model.id
        )
    }

    /// A block as wide and long as its chairs stand, counted in standard seat pitches.
    private static func seatingBlock(around chairs: [Placement], number: Int) -> LayoutObject {
        let corners = chairs.flatMap { LayoutGeometry.corners(of: $0) }
        let low = corners.reduce(corners[0]) { SIMD2(min($0.x, $1.x), min($0.y, $1.y)) }
        let high = corners.reduce(corners[0]) { SIMD2(max($0.x, $1.x), max($0.y, $1.y)) }
        let pitch = FurnitureModels.seatPitchM
        let size = SIMD2(
            Double(FurnitureModels.seatsAlong(high.x - low.x)) * pitch,
            Double(FurnitureModels.seatsAlong(high.y - low.y)) * pitch
        )
        return LayoutObject(
            kind: .seating,
            label: "Seating \(number)",
            placement: Placement(center: (low + high) / 2, sizeM: size),
            reviewState: .detected,
            catalogID: FurnitureModels.seatingBlockID
        )
    }

    /// A swing symbol that sits on a wall gap is already the opening, so it makes no second door.
    static func swingDoorsNotOnOpenings(in items: [DetectedItem]) -> [DetectedItem] {
        let openings = items.filter { $0.cls == "opening" }
        return items.filter { item in
            item.cls == "door" && !openings.contains { overlaps($0.box, item.box) }
        }
    }

    /// The symbol box includes the swing arc, so the door is its long side and a thin leaf.
    static func swingDoor(from frame: Placement) -> LayoutObject {
        let size = frame.sizeM
        let isVertical = size.y > size.x * 1.2
        return LayoutObject(
            kind: .door,
            label: "Door",
            placement: Placement(
                center: frame.center,
                sizeM: SIMD2(max(size.x, size.y), swingDoorThicknessM),
                rotationRadians: isVertical ? .pi / 2 : 0
            ),
            doorFlow: DoorFlow(direction: .both),
            reviewState: .detected
        )
    }

    /// A gate stands in an open passage, so it has no wall for `WallConnections` to seat it on and is added after.
    static func gateDoors(in items: [DetectedItem], frame: (DetectedItem) -> Placement) -> [LayoutObject] {
        items.filter { $0.cls == "gate" }.map { swingDoor(from: frame($0)) }
    }

    private static let swingDoorThicknessM = 0.3
    private static let mainDoorShare = 0.5

    /// A plan draws every door it has: service rooms, toilets, fire exits. Every open door lets visitors in and
    /// out of the simulation, and the doors an event uses are the widest ones, so a door under half as wide as
    /// the widest arrives closed. It stays in the layout for the user to open.
    static func closingSideDoors(_ objects: [LayoutObject]) -> [LayoutObject] {
        func width(_ door: LayoutObject) -> Double { max(door.placement.sizeM.x, door.placement.sizeM.y) }
        let widest = objects.filter { $0.kind == .door }.map(width).max() ?? 0
        return objects.map { object in
            guard object.kind == .door, width(object) < widest * mainDoorShare else { return object }
            var door = object
            door.doorFlow = DoorFlow(direction: .disabled)
            return door
        }
    }
    private static let rowOverlap = 0.8

    /// Swing symbols side by side are one row of doors that was read in pieces where a leaf was missed. Two symbols
    /// with a wall between them open into different rooms and stay apart.
    static func joinedDoorRows(_ frames: [Placement], walls: [Placement]) -> [Placement] {
        var rows = frames.map { LayoutGeometry.bounds(of: $0) }
        let partitions = walls.map { LayoutGeometry.bounds(of: $0) }
        var joined = true
        while joined {
            joined = false
            search: for first in rows.indices {
                for second in rows.indices where second > first
                    && standInOneRow(rows[first], rows[second], partitions: partitions) {
                    rows[first] = BoundingBox(
                        minX: min(rows[first].minX, rows[second].minX),
                        maxX: max(rows[first].maxX, rows[second].maxX),
                        minY: min(rows[first].minY, rows[second].minY),
                        maxY: max(rows[first].maxY, rows[second].maxY)
                    )
                    rows.remove(at: second)
                    joined = true
                    break search
                }
            }
        }
        return rows.map { row in
            Placement(
                center: SIMD2((row.minX + row.maxX) / 2, (row.minY + row.maxY) / 2),
                sizeM: SIMD2(row.maxX - row.minX, row.maxY - row.minY)
            )
        }
    }

    /// The gap between the two is at most one leaf, they are level with each other, and no wall crosses between
    /// their centres. A row can run along either axis.
    private static func standInOneRow(_ first: BoundingBox, _ second: BoundingBox, partitions: [BoundingBox]) -> Bool {
        func spans(_ box: BoundingBox) -> (low: SIMD2<Double>, high: SIMD2<Double>) {
            (SIMD2(box.minX, box.minY), SIMD2(box.maxX, box.maxY))
        }
        let (one, other) = (spans(first), spans(second))
        return [0, 1].contains { along in
            let across = 1 - along
            let gap = max(one.low[along], other.low[along]) - min(one.high[along], other.high[along])
            let leaf = min(one.high[across] - one.low[across], other.high[across] - other.low[across])
            let levelLow = max(one.low[across], other.low[across])
            let levelHigh = min(one.high[across], other.high[across])
            guard gap <= leaf, levelHigh - levelLow >= leaf * rowOverlap else { return false }
            let centres = [one, other].map { ($0.low[along] + $0.high[along]) / 2 }.sorted()
            return !partitions.contains { wall in
                let (low, high) = spans(wall)
                return high[across] - low[across] > high[along] - low[along]
                    && low[along] >= centres[0] && high[along] <= centres[1]
                    && low[across] < levelHigh && high[across] > levelLow
            }
        }
    }

    private static func smallestGroup(holding point: SIMD2<Double>, among groups: [DetectedItem]) -> DetectedItem? {
        groups
            .filter { contains($0.box, point) }
            .min { $0.box[2] * $0.box[3] < $1.box[2] * $1.box[3] }
    }

    private static func centre(of box: [Double]) -> SIMD2<Double> {
        SIMD2(box[0] + box[2] / 2, box[1] + box[3] / 2)
    }

    private static func contains(_ box: [Double], _ point: SIMD2<Double>) -> Bool {
        point.x >= box[0] && point.x <= box[0] + box[2] && point.y >= box[1] && point.y <= box[1] + box[3]
    }

    private static func overlaps(_ first: [Double], _ second: [Double]) -> Bool {
        first[0] < second[0] + second[2] && second[0] < first[0] + first[2]
            && first[1] < second[1] + second[3] && second[1] < first[1] + first[3]
    }
}

/// The standard table and angle whose seats best match the chairs found around a table.
struct FurnitureFit {
    let model: TableModel
    let angleDegrees: Int
    let centre: SIMD2<Double>

    private static let angleStepDegrees = 45

    static func best(at centre: SIMD2<Double>, chairCentres: [SIMD2<Double>]) -> FurnitureFit {
        let seatCounts = FurnitureModels.tables.map(\.seatCount)
        let closestCount = seatCounts.min { abs($0 - chairCentres.count) < abs($1 - chairCentres.count) }
        var best = FurnitureFit(model: FurnitureModels.tables[0], angleDegrees: 0, centre: centre)
        var bestCost = Double.infinity
        for model in FurnitureModels.tables where model.seatCount == closestCount {
            for angle in stride(from: 0, to: 360, by: angleStepDegrees) {
                let cost = mismatch(of: model, angleDegrees: angle, at: centre, chairCentres: chairCentres)
                if cost < bestCost {
                    bestCost = cost
                    best = FurnitureFit(model: model, angleDegrees: angle, centre: centre)
                }
            }
        }
        return best
    }

    /// How far chairs and seats are from each other, each to its nearest.
    private static func mismatch(
        of model: TableModel,
        angleDegrees: Int,
        at centre: SIMD2<Double>,
        chairCentres: [SIMD2<Double>]
    ) -> Double {
        let angle = Double(angleDegrees) * .pi / 180
        let seats = FurnitureModels.seatOffsets(of: model).map { offset in
            centre + SIMD2(
                offset.x * cos(angle) - offset.y * sin(angle),
                offset.x * sin(angle) + offset.y * cos(angle)
            )
        }
        let chairToSeat = chairCentres.map { chair in seats.map { simd_length($0 - chair) }.min() ?? 0 }
        let seatToChair = seats.map { seat in chairCentres.map { simd_length($0 - seat) }.min() ?? 0 }
        return chairToSeat.reduce(0, +) + seatToChair.reduce(0, +)
    }
}
