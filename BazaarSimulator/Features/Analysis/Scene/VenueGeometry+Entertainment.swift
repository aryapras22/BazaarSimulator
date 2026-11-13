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
