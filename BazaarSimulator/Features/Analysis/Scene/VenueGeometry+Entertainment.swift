import Foundation
import simd

extension VenueGeometry {
    /// An attraction, told apart by its label: a photobooth, a display or competition area, or a stage.
    /// Its front is its first open side, or the bottom side of the plan when none is open.
    static func entertainment(_ object: LayoutObject) -> [VenueBlock] {
        let front = [OpenSides.bottom, .top, .left, .right].first { object.openSides.contains($0) } ?? .bottom
        var (width, depth) = size(of: object)
        let quarterTurns: Float
        switch front {
        case .top: quarterTurns = 2
        case .right: quarterTurns = 1
        case .left: quarterTurns = -1
        default: quarterTurns = 0
        }
        if front == .left || front == .right { swap(&width, &depth) }
        // Parts are described with the front toward +z, then the whole frame is turned to the real front.
        let base = Frame(object)
        let frame = Frame(middle: base.middle, turn: base.turn + quarterTurns * .pi / 2)

        let label = object.label.lowercased()
        if label.contains("photo") {
            return photobooth(width: width, depth: depth, frame: frame)
        }
        if ["display", "competition", "lomba"].contains(where: label.contains) {
            return display(width: width, depth: depth, frame: frame)
        }
        return stage(width: width, depth: depth, height: Float(object.heightM ?? 0.5), frame: frame)
    }

    // MARK: Stage

    /// A raised deck with a backdrop hung from a truss at the back, speakers at the front corners, lamps
    /// under the truss, and steps up the front.
    private static func stage(width: Float, depth: Float, height: Float, frame: Frame) -> [VenueBlock] {
        let back = -depth / 2
        let trussHeight: Float = 3.0
        var parts = [
            frame.part(at: SIMD3(0, height / 2, 0), size: SIMD3(width, height, depth), color: coralColor),
            frame.part(
                at: SIMD3(0, height + 1.3, back + 0.2), size: SIMD3(max(width - 0.5, 0.2), 2.6, 0.08), color: cobaltColor
            ),
            frame.part(
                at: SIMD3(0, height + trussHeight, back + 0.2), size: SIMD3(width, 0.16, 0.16), color: frameColor
            )
        ]
        for side in [Float(-1), 1] {
            let across = side * (width / 2 - 0.08)
            parts.append(frame.part(
                .cylinder, at: SIMD3(across, height + trussHeight / 2, back + 0.2),
                size: SIMD3(0.14, trussHeight, 0.14), color: frameColor
            ))
            parts.append(frame.part(
                at: SIMD3(side * (width / 2 - 0.45), height + 0.45, depth / 2 - 0.4), size: SIMD3(0.5, 0.9, 0.4),
                color: frameColor
            ))
        }
        let lamps = max(2, Int(width / 1.5))
        for index in 0..<lamps {
            let across = (Float(index) - Float(lamps - 1) / 2) * (width - 1) / Float(max(lamps - 1, 1))
            parts.append(frame.part(
                .cylinder, at: SIMD3(across, height + trussHeight - 0.2, back + 0.2), size: SIMD3(0.2, 0.24, 0.2),
                color: yellowColor
            ))
        }
        let stepWidth = min(1.4, width * 0.5)
        for step in 0..<2 {
            let rise = height * Float(2 - step) / 3
            parts.append(frame.part(
                at: SIMD3(0, rise / 2, depth / 2 + 0.15 + 0.3 * Float(step)), size: SIMD3(stepWidth, rise, 0.3),
                color: creamColor
            ))
        }
        return parts
    }

    // MARK: Photobooth

    /// A cabin closed on three sides, with a curtain half across the front, a bench inside, and a sign on
    /// the roof.
    private static func photobooth(width: Float, depth: Float, frame: Frame) -> [VenueBlock] {
        let wallHeight: Float = 2.1
        let thickness: Float = 0.08
        var parts = [
            frame.part(at: SIMD3(0, 0.04, 0), size: SIMD3(width, 0.08, depth), color: paleBlueColor),
            frame.part(
                at: SIMD3(0, wallHeight / 2, -depth / 2 + thickness / 2), size: SIMD3(width, wallHeight, thickness),
                color: vermilionColor
            )
        ]
        for side in [Float(-1), 1] {
            parts.append(frame.part(
                at: SIMD3(side * (width / 2 - thickness / 2), wallHeight / 2, 0), size: SIMD3(thickness, wallHeight, depth),
                color: vermilionColor
            ))
        }
        parts += [
            frame.part(at: SIMD3(0, wallHeight + 0.05, 0), size: SIMD3(width + 0.1, 0.1, depth + 0.1), color: whiteColor),
            frame.part(
                at: SIMD3(-width / 4 + thickness / 2, 0.08 + 0.95, depth / 2 - 0.05), size: SIMD3(width / 2 - thickness, 1.9, 0.04),
                color: cobaltColor
            ),
            frame.part(
                at: SIMD3(0, 0.08 + 0.225, -depth / 2 + thickness + 0.2), size: SIMD3(max(width - 0.5, 0.2), 0.45, 0.4),
                color: creamColor
            ),
            frame.part(
                at: SIMD3(0, wallHeight + 0.1 + 0.2, depth / 2 - 0.1), size: SIMD3(width * 0.7, 0.4, 0.08), color: yellowColor
            )
        ]
        return parts
    }

    // MARK: Display

    /// A low platform fenced with posts and rails on every side but the front, with a plinth in the middle
    /// and something on it to look at.
    private static func display(width: Float, depth: Float, frame: Frame) -> [VenueBlock] {
        let deck: Float = 0.15
        let postHeight: Float = 0.9
        let inset: Float = 0.12
        var parts = [frame.part(at: SIMD3(0, deck / 2, 0), size: SIMD3(width, deck, depth), color: coralColor)]
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            parts.append(frame.part(
                .cylinder, at: SIMD3(sx * (width / 2 - inset), deck + postHeight / 2, sz * (depth / 2 - inset)),
                size: SIMD3(0.08, postHeight, 0.08), color: cobaltColor
            ))
        }
        let railHeight = deck + postHeight - 0.1
        parts.append(frame.part(
            at: SIMD3(0, railHeight, -(depth / 2 - inset)), size: SIMD3(width - inset * 2, 0.04, 0.04), color: cobaltColor
        ))
        for side in [Float(-1), 1] {
            parts.append(frame.part(
                at: SIMD3(side * (width / 2 - inset), railHeight, 0), size: SIMD3(0.04, 0.04, depth - inset * 2),
                color: cobaltColor
            ))
        }
        let plinth = min(width, depth) * 0.3
        parts += [
            frame.part(at: SIMD3(0, deck + 0.5, 0), size: SIMD3(plinth, 1.0, plinth), color: whiteColor),
            frame.part(
                .cylinder, at: SIMD3(0, deck + 1.0 + 0.25, 0), size: SIMD3(plinth * 0.6, 0.5, plinth * 0.6), color: yellowColor
            )
        ]
        return parts
    }
}
