import Foundation
import simd

/// A standard table: its size and its seats are fixed by the model, so a table never depends on how it was drawn.
struct TableModel: Hashable, Sendable {
    enum Shape: Hashable, Sendable {
        case rect
        case round
    }

    let id: String
    let name: String
    let shape: Shape
    let sizeM: SIMD2<Double>
    let seatCount: Int
}

/// The standard tables and the standard seat, and where the chairs of a table or a seating block stand.
/// Chairs are never stored on a layout. They follow from the model, the size and the rotation of their object.
enum FurnitureModels {
    static let chairSizeM = SIMD2<Double>(0.4, 0.4)
    static let chairGapM = 0.05
    /// The distance between chairs in a seating block.
    static let seatPitchM = 0.5
    static let tableHeightM = 0.75
    static let chairHeightM = 0.45

    static let tables: [TableModel] = [
        TableModel(
            id: "table-rect-2", name: "Rectangular table, 2 seats", shape: .rect, sizeM: SIMD2(1.2, 0.7), seatCount: 2
        ),
        TableModel(
            id: "table-rect-4", name: "Rectangular table, 4 seats", shape: .rect, sizeM: SIMD2(1.2, 0.7), seatCount: 4
        ),
        TableModel(
            id: "table-rect-6", name: "Rectangular table, 6 seats", shape: .rect, sizeM: SIMD2(1.8, 0.76), seatCount: 6
        ),
        TableModel(
            id: "table-round-4", name: "Round table, 4 seats", shape: .round, sizeM: SIMD2(1.0, 1.0), seatCount: 4
        ),
        TableModel(
            id: "table-round-6", name: "Round table, 6 seats", shape: .round, sizeM: SIMD2(1.5, 1.5), seatCount: 6
        ),
        TableModel(
            id: "table-round-8", name: "Round table, 8 seats", shape: .round, sizeM: SIMD2(1.8, 1.8), seatCount: 8
        )
    ]

    static let seatingBlockID = "seating-block"
    static let seatingBlockSizeM = SIMD2<Double>(3.0, 2.0)

    static func table(_ id: String?) -> TableModel? {
        tables.first { $0.id == id }
    }

    /// Chair centres in the table's own frame: x along its width, y along its length, before any rotation.
    static func seatOffsets(of model: TableModel) -> [SIMD2<Double>] {
        switch model.shape {
        case .round:
            let radius = model.sizeM.x / 2 + chairGapM + chairSizeM.x / 2
            return (0..<model.seatCount).map { index in
                let angle = 2 * Double.pi * Double(index) / Double(model.seatCount)
                return SIMD2(radius * cos(angle), radius * sin(angle))
            }
        case .rect:
            return rectSeatOffsets(of: model)
        }
    }

    /// Chair centres of a seating block of this size, centred on it, one chair per seat pitch.
    static func gridOffsets(for size: SIMD2<Double>) -> [SIMD2<Double>] {
        let columns = seatsAlong(size.x)
        let rows = seatsAlong(size.y)
        return (0..<rows).flatMap { row in
            (0..<columns).map { column in
                SIMD2(
                    (Double(column) - Double(columns - 1) / 2) * seatPitchM,
                    (Double(row) - Double(rows - 1) / 2) * seatPitchM
                )
            }
        }
    }

    static func seatsAlong(_ length: Double) -> Int {
        max(1, Int((length / seatPitchM).rounded()))
    }

    /// The chairs of a table or a seating block as they stand on the plan. Other kinds have none.
    static func chairs(of object: LayoutObject) -> [Placement] {
        let offsets: [SIMD2<Double>]
        switch object.kind {
        case .table:
            guard let model = table(object.catalogID) else { return [] }
            offsets = seatOffsets(of: model)
        case .seating:
            offsets = gridOffsets(for: object.placement.sizeM)
        default:
            return []
        }
        let placement = object.placement
        let cosine = cos(placement.rotationRadians)
        let sine = sin(placement.rotationRadians)
        return offsets.map { offset in
            Placement(
                center: SIMD2(
                    placement.center.x + offset.x * cosine - offset.y * sine,
                    placement.center.y + offset.x * sine + offset.y * cosine
                ),
                sizeM: chairSizeM,
                rotationRadians: placement.rotationRadians
            )
        }
    }

    /// Half the seats along each long side, evenly spaced.
    private static func rectSeatOffsets(of model: TableModel) -> [SIMD2<Double>] {
        let sideY = model.sizeM.y / 2 + chairGapM + chairSizeM.y / 2
        let perSide = model.seatCount / 2
        let spacing = model.sizeM.x / Double(perSide)
        return (0..<perSide).flatMap { index -> [SIMD2<Double>] in
            let along = (Double(index) - Double(perSide - 1) / 2) * spacing
            return [SIMD2(along, sideY), SIMD2(along, -sideY)]
        }
    }
}
