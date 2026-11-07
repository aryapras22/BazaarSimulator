import Foundation
import simd

extension ExtractedLayoutMapper {
    /// Tables and chairs as drawn. A chair belongs to the table inside the smallest group box that holds the chair,
    /// so rows of audience chairs, which have a group but no table, stay unlinked.
    static func furniture(from items: [DetectedItem], frame: (DetectedItem) -> Placement) -> [LayoutFurniture] {
        let objects = items.filter { $0.cls == "object" }
        let groups = objects.filter { $0.kind == "chair_group" }
        let tables = objects.filter { $0.kind == "table" }.map {
            (box: $0.box, piece: LayoutFurniture(kind: .table, placement: frame($0)))
        }

        var result = tables.map(\.piece)
        for chair in objects where chair.kind == "chair" {
            let owner = owningTable(of: chair.box, tables: tables, groups: groups)
            result.append(LayoutFurniture(kind: .chair, placement: frame(chair), tableID: owner?.id))
        }
        return result
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

    private static let swingDoorThicknessM = 0.3

    private static func owningTable(
        of chairBox: [Double],
        tables: [(box: [Double], piece: LayoutFurniture)],
        groups: [DetectedItem]
    ) -> LayoutFurniture? {
        let chairCentre = centre(of: chairBox)
        guard let group = groups
            .filter({ contains($0.box, chairCentre) })
            .min(by: { $0.box[2] * $0.box[3] < $1.box[2] * $1.box[3] })
        else { return nil }
        return tables
            .filter { contains(group.box, centre(of: $0.box)) }
            .min { distance(centre(of: $0.box), chairCentre) < distance(centre(of: $1.box), chairCentre) }?
            .piece
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

    private static func distance(_ first: SIMD2<Double>, _ second: SIMD2<Double>) -> Double {
        simd_length(first - second)
    }
}
