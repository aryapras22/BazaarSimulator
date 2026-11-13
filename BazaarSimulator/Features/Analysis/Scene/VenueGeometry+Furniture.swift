import Foundation
import simd

extension VenueGeometry {
    private static let tableTopThickness: Float = 0.06
    private static let chairSeatHeight = Float(FurnitureModels.chairHeightM)
    private static let chairSize = Float(FurnitureModels.chairSizeM.x)

    // MARK: Tables

    /// A table with its chairs. A round table stands on a pedestal and a rectangular one on four legs. The
    /// chairs are where the table's model puts its seats, each turned to face the table.
    static func table(_ object: LayoutObject) -> [VenueBlock] {
        let (width, depth) = size(of: object)
        let frame = Frame(object)
        let model = FurnitureModels.table(object.catalogID)
        let isRound = model.map { $0.shape == .round } ?? (object.placement.shape == .round)
        let height = Float(FurnitureModels.tableHeightM)
        let legHeight = height - tableTopThickness

        var parts: [VenueBlock]
        if isRound {
            let diameter = min(width, depth)
            parts = [
                frame.part(
                    .cylinder, at: SIMD3(0, height - tableTopThickness / 2, 0),
                    size: SIMD3(diameter, tableTopThickness, diameter), color: yellowColor
                ),
                frame.part(.cylinder, at: SIMD3(0, legHeight / 2, 0), size: SIMD3(0.12, legHeight, 0.12), color: frameColor),
                frame.part(.cylinder, at: SIMD3(0, 0.02, 0), size: SIMD3(diameter * 0.5, 0.04, diameter * 0.5), color: frameColor)
            ]
        } else {
            parts = [frame.part(
                at: SIMD3(0, height - tableTopThickness / 2, 0), size: SIMD3(width, tableTopThickness, depth), color: yellowColor
            )]
            let inset: Float = 0.08
            for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
                parts.append(frame.part(
                    at: SIMD3(sx * (width / 2 - inset), legHeight / 2, sz * (depth / 2 - inset)),
                    size: SIMD3(0.06, legHeight, 0.06), color: frameColor
                ))
            }
        }
        for seat in model.map(FurnitureModels.seatOffsets) ?? [] {
            let offset = SIMD2(Float(seat.x), Float(seat.y))
            parts += chair(at: offset, facing: -simd_normalize(offset), in: frame)
        }
        return parts
    }

    // MARK: Seating

    /// Rows of chairs on a mat. They face `target` (a point on the plan, such as the nearest stage) along
    /// whichever of the block's own sides points at it most directly, or the block's top side without one.
    static func seating(_ object: LayoutObject, toward target: SIMD2<Double>? = nil) -> [VenueBlock] {
        let (width, depth) = size(of: object)
        let frame = Frame(object)
        var facing = SIMD2<Float>(0, -1)
        if let target {
            let away = target - object.placement.center
            let turn = object.placement.rotationRadians
            let local = SIMD2(
                Float(away.x * cos(turn) + away.y * sin(turn)), Float(-away.x * sin(turn) + away.y * cos(turn))
            )
            facing = abs(local.x) > abs(local.y) ? SIMD2(local.x < 0 ? -1 : 1, 0) : SIMD2(0, local.y < 0 ? -1 : 1)
        }
        var parts = [frame.part(at: SIMD3(0, 0.01, 0), size: SIMD3(width, 0.02, depth), color: paleBlueColor)]
        for seat in FurnitureModels.gridOffsets(for: object.placement.sizeM) {
            parts += chair(at: SIMD2(Float(seat.x), Float(seat.y)), facing: facing, in: frame)
        }
        return parts
    }

    // MARK: Chairs

    /// A chair: a seat, a back, and four legs. `offset` is where it stands in its object's frame and
    /// `direction` is the way a person sitting on it looks, both across (x) and along the depth (y).
    static func chair(at offset: SIMD2<Float>, facing direction: SIMD2<Float>, in frame: Frame) -> [VenueBlock] {
        let turn = atan2(direction.x, direction.y)
        /// `across` is the chair's own left and right, `forward` the way it faces.
        func place(_ across: Float, _ height: Float, _ forward: Float) -> SIMD3<Float> {
            SIMD3(
                offset.x + across * cos(turn) + forward * sin(turn), height,
                offset.y - across * sin(turn) + forward * cos(turn)
            )
        }
        let legHeight = chairSeatHeight - 0.05
        let legReach = chairSize / 2 - 0.03
        var parts = [
            frame.part(
                at: place(0, chairSeatHeight - 0.025, 0), size: SIMD3(chairSize, 0.05, chairSize),
                color: creamColor, extraTurn: turn
            ),
            frame.part(
                at: place(0, chairSeatHeight + 0.2, -(chairSize / 2 - 0.025)), size: SIMD3(chairSize, 0.4, 0.05),
                color: creamColor, extraTurn: turn
            )
        ]
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            parts.append(frame.part(
                at: place(sx * legReach, legHeight / 2, sz * legReach), size: SIMD3(0.04, legHeight, 0.04),
                color: frameColor, extraTurn: turn
            ))
        }
        return parts
    }
}
