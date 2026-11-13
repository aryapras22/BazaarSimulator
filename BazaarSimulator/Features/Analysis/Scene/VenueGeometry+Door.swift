import Foundation
import simd

extension VenueGeometry {
    // MARK: Doors

    private static let doorFrameHeight: Float = 2.3
    private static let leafAngle: Float = 70 * .pi / 180

    /// A door: a frame of two posts and a beam, a leaf standing open, and a colored strip on the floor that
    /// shows which way people may go. A wide door has two leaves, and a door in use carries a colored sign
    /// over its beam. A disabled door is just the frame and a gray strip.
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

        if object.doorFlow?.direction != .disabled {
            // Each leaf is hinged at a post and swung open, so the doorway reads as a doorway.
            let clear = max(opening - postSize * 2, 0.2)
            let isDouble = opening >= 1.5
            let leafWidth = isDouble ? clear / 2 : clear
            for end in isDouble ? [Float(-1), 1] : [Float(-1)] {
                let hinge = end * (opening / 2 - postSize)
                let leafAlong = hinge - end * leafWidth / 2 * cos(leafAngle)
                let swing = opensAlongWidth ? end * leafAngle : -end * leafAngle - .pi / 2 * (end < 0 ? 1 : -1)
                parts.append(frame.part(
                    at: place(leafAlong, 1.05, leafWidth / 2 * sin(leafAngle)),
                    size: SIMD3(leafWidth, 2.1, 0.05),
                    color: color,
                    extraTurn: swing
                ))
            }
            parts.append(frame.part(
                at: place(0, doorFrameHeight + 0.15 + 0.14, 0), size: sized(min(opening * 0.6, 1.2), 0.28, 0.08), color: color
            ))
        }
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
