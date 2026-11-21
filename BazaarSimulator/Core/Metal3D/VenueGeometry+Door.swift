import Foundation
import simd

extension VenueGeometry {
    // MARK: Doors

    private static let doorFrameHeight: Float = 2.3
    private static let leafAngle: Float = 70 * .pi / 180

    /// A door: a frame of two posts and a beam, a leaf standing open, and a colored strip on the floor that
    /// shows which way people may go. A wide door has two leaves. Each leaf has a window and a handle. A door
    /// in use lies on a mat of its own color and carries a sign over its beam. A disabled door is shut and
    /// barred.
    static func door(_ object: LayoutObject) -> [VenueBlock] {
        let (width, depth) = size(of: object)
        let frame = Frame(object)
        let opensAlongWidth = width >= depth
        let opening = opensAlongWidth ? width : depth
        let thickness = opensAlongWidth ? depth : width
        let color = doorColor(for: object)

        // Parts are described along the opening and across it, then placed on the right axes.
        func place(_ along: Float, _ height: Float, _ across: Float) -> SIMD3<Float> {
            opensAlongWidth ? SIMD3(along, height, across) : SIMD3(across, height, along)
        }
        func sized(_ along: Float, _ height: Float, _ across: Float) -> SIMD3<Float> {
            opensAlongWidth ? SIMD3(along, height, across) : SIMD3(across, height, along)
        }

        let postSize: Float = 0.12
        let reach = thickness + 0.12
        var parts = [
            frame.part(at: place(0, 0.02, 0), size: sized(opening, 0.04, thickness), color: color),
            frame.part(
                at: place(0, doorFrameHeight + 0.075, 0), size: sized(opening, 0.15, reach), color: frameColor
            )
        ]
        for end in [Float(-1), 1] {
            parts.append(frame.part(
                at: place(end * (opening / 2 - postSize / 2), doorFrameHeight / 2, 0),
                size: sized(postSize, doorFrameHeight, reach), color: frameColor
            ))
        }

        let clear = max(opening - postSize * 2, 0.2)
        if object.doorFlow?.direction == .disabled {
            // Shut, and barred across both faces, so it does not read as a way through.
            parts += [
                frame.part(at: place(0, 1.05, 0), size: sized(clear, 2.1, reach - 0.02), color: color),
                frame.part(at: place(0, 1.0, 0), size: sized(opening + 0.3, 0.12, reach + 0.1), color: vermilionColor)
            ]
            return parts
        }

        // Each leaf is hinged at a post and swung open, so the doorway reads as a doorway.
        let isDouble = opening >= 1.5
        let leafWidth = isDouble ? clear / 2 : clear
        for end in isDouble ? [Float(-1), 1] : [Float(-1)] {
            let hinge = end * (opening / 2 - postSize)
            let swing = opensAlongWidth ? end * leafAngle : -end * leafAngle - .pi / 2 * (end < 0 ? 1 : -1)
            /// A part of the leaf, `along` it from the hinge.
            func onLeaf(_ along: Float, _ height: Float, _ size: SIMD3<Float>, _ color: SIMD4<Float>) -> VenueBlock {
                frame.part(
                    at: place(hinge - end * along * cos(leafAngle), height, along * sin(leafAngle)),
                    size: size, color: color, extraTurn: swing
                )
            }
            parts += [
                onLeaf(leafWidth / 2, 1.05, SIMD3(leafWidth, 2.1, 0.05), color),
                onLeaf(leafWidth / 2, 1.45, SIMD3(leafWidth * 0.6, 0.9, 0.065), paleBlueColor),
                onLeaf(leafWidth - 0.12, 1.0, SIMD3(0.1, 0.05, 0.14), frameColor)
            ]
        }
        let tint = SIMD4(simd_mix(SIMD3(color.x, color.y, color.z), SIMD3<Float>(1, 1, 1), SIMD3<Float>(repeating: 0.6)), 1)
        let signHeight = doorFrameHeight + 0.15 + 0.14
        let signWidth = min(opening * 0.6, 1.2)
        parts += [
            frame.part(at: place(0, 0.01, 0), size: sized(max(opening - 0.24, 0.2), 0.02, thickness + 1.2), color: tint),
            frame.part(at: place(0, signHeight, 0), size: sized(signWidth * 0.7, 0.12, 0.1), color: whiteColor),
            frame.part(at: place(0, signHeight, 0), size: sized(signWidth, 0.28, 0.08), color: color)
        ]
        return parts
    }

    static func doorColor(for object: LayoutObject) -> SIMD4<Float> {
        switch object.doorFlow?.direction {
        case .entrance: SIMD4(0.18, 0.62, 0.42, 1)
        case .exit: SIMD4(0.85, 0.20, 0.22, 1)
        case .disabled: SIMD4(0.62, 0.64, 0.68, 1)
        default: SIMD4(0.20, 0.38, 0.75, 1)
        }
    }
}
