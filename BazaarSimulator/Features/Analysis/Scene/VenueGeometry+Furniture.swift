import Foundation
import simd

extension VenueGeometry {
    private static let tableTopThickness: Float = 0.06
    private static let chairSeatHeight = Float(FurnitureModels.chairHeightM)
    private static let chairSize = Float(FurnitureModels.chairSizeM.x)
    private static let chairBackHeight: Float = 0.88

    // MARK: Tables

    /// A table with its chairs. A round table stands on a pedestal and a rectangular one on four legs. The
    /// chairs are where the table's model puts its seats, each turned to face the table, and the table is
    /// laid for them.
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
        let seats = (model.map(FurnitureModels.seatOffsets) ?? []).map { SIMD2(Float($0.x), Float($0.y)) }
        parts += tableSetting(
            seats: seats, isRound: isRound, reach: isRound ? min(width, depth) / 2 : depth / 2, height: height, frame: frame
        )
        for offset in seats {
            parts += chair(at: offset, facing: -simd_normalize(offset), in: frame)
        }
        return parts
    }

    /// What is on a table: something in the middle, and a plate and a cup in front of each seat. A round
    /// table also has a cloth hanging under its top. `reach` is how far the top goes toward the seats.
    private static func tableSetting(
        seats: [SIMD2<Float>], isRound: Bool, reach: Float, height: Float, frame: Frame
    ) -> [VenueBlock] {
        var parts: [VenueBlock] = []
        if isRound {
            let cloth = reach * 2 - 0.04
            parts += [
                frame.part(.cylinder, at: SIMD3(0, height - 0.2, 0), size: SIMD3(cloth, 0.28, cloth), color: whiteColor),
                frame.part(.cylinder, at: SIMD3(0, height + 0.09, 0), size: SIMD3(0.1, 0.18, 0.1), color: cobaltColor),
                frame.part(.cylinder, at: SIMD3(0, height + 0.22, 0), size: SIMD3(0.18, 0.08, 0.18), color: coralColor)
            ]
        } else {
            parts.append(frame.part(at: SIMD3(0, height + 0.07, 0), size: SIMD3(0.1, 0.14, 0.1), color: frameColor))
        }
        for seat in seats {
            // Toward the seat from the table's middle, and sideways along the table's edge.
            let out = isRound ? simd_normalize(seat) : SIMD2(0, seat.y < 0 ? -1 : 1)
            let along = SIMD2(-out.y, out.x)
            let plate = isRound ? out * (reach - 0.2) : SIMD2(seat.x, out.y * (reach - 0.17))
            let cup = plate + along * 0.17
            parts += [
                frame.part(.cylinder, at: SIMD3(plate.x, height + 0.01, plate.y), size: SIMD3(0.2, 0.02, 0.2), color: whiteColor),
                frame.part(.cylinder, at: SIMD3(cup.x, height + 0.045, cup.y), size: SIMD3(0.07, 0.09, 0.07), color: coralColor)
            ]
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

    /// A chair: a seat on two front legs, and two back legs that carry on up to hold a backrest, with a gap
    /// between the seat and the backrest. `offset` is where it stands in its object's frame and `direction`
    /// is the way a person sitting on it looks, both across (x) and along the depth (y).
    static func chair(at offset: SIMD2<Float>, facing direction: SIMD2<Float>, in frame: Frame) -> [VenueBlock] {
        let turn = atan2(direction.x, direction.y)
        /// `across` is the chair's own left and right, `forward` the way it faces.
        func part(_ across: Float, _ height: Float, _ forward: Float, _ size: SIMD3<Float>, _ color: SIMD4<Float>) -> VenueBlock {
            frame.part(
                at: SIMD3(
                    offset.x + across * cos(turn) + forward * sin(turn), height,
                    offset.y - across * sin(turn) + forward * cos(turn)
                ),
                size: size, color: color, extraTurn: turn
            )
        }
        let reach = chairSize / 2 - 0.02
        let legHeight = chairSeatHeight - 0.05
        var parts = [
            part(0, chairSeatHeight - 0.025, 0, SIMD3(chairSize, 0.05, chairSize), creamColor),
            part(0, chairBackHeight - 0.13, -reach, SIMD3(chairSize, 0.22, 0.03), creamColor)
        ]
        for side in [Float(-1), 1] {
            parts += [
                part(side * reach, legHeight / 2, reach, SIMD3(0.04, legHeight, 0.04), frameColor),
                part(side * reach, chairBackHeight / 2, -reach, SIMD3(0.04, chairBackHeight, 0.04), frameColor)
            ]
        }
        return parts
    }
}
