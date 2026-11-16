import Foundation
import simd

extension VenueGeometry {
    private static let cabinWallHeight: Float = 2.1
    private static let cabinWall: Float = 0.08
    private static let curtainShade = SIMD4<Float>(0.15, 0.29, 0.60, 1)

    /// A photo cabin at the back left of the footprint, and beside it, when there is room, an open set with
    /// a backdrop, a camera on a stand and a light. The front is toward +z.
    static func photobooth(width: Float, depth: Float, frame: Frame) -> [VenueBlock] {
        let cabinWidth = min(width, 2.2), cabinDepth = min(depth, 2.0)
        let middle = SIMD2(-width / 2 + cabinWidth / 2, -depth / 2 + cabinDepth / 2)
        var parts = [frame.part(at: SIMD3(0, 0.04, 0), size: SIMD3(width, 0.08, depth), color: paleBlueColor)]
        parts += cabinShell(width: cabinWidth, depth: cabinDepth, middle: middle, frame: frame)
        parts += cabinFront(width: cabinWidth, front: middle.y + cabinDepth / 2, middle: middle.x, frame: frame)
        let spare = width - cabinWidth
        if spare >= 1.2 {
            parts += photoSet(width: spare - 0.3, depth: depth, middle: width / 2 - spare / 2, frame: frame)
        }
        return parts
    }

    /// Three walls and a roof, a stool inside, a lit sign on the roof, and a strip of photos on the outer wall.
    private static func cabinShell(width: Float, depth: Float, middle: SIMD2<Float>, frame: Frame) -> [VenueBlock] {
        let height = cabinWallHeight, wall = cabinWall
        let left = middle.x - width / 2 + wall / 2
        var parts = [
            frame.part(
                at: SIMD3(middle.x, height / 2, middle.y - depth / 2 + wall / 2), size: SIMD3(width, height, wall),
                color: vermilionColor
            ),
            frame.part(at: SIMD3(left, height / 2, middle.y), size: SIMD3(wall, height, depth), color: vermilionColor),
            frame.part(
                at: SIMD3(middle.x + width / 2 - wall / 2, height / 2, middle.y), size: SIMD3(wall, height, depth),
                color: vermilionColor
            ),
            frame.part(
                at: SIMD3(middle.x, height + 0.05, middle.y), size: SIMD3(width + 0.1, 0.1, depth + 0.1), color: whiteColor
            ),
            frame.part(
                .cylinder, at: SIMD3(middle.x - width / 4, 0.08 + 0.225, middle.y), size: SIMD3(0.35, 0.45, 0.35),
                color: creamColor
            ),
            frame.part(at: SIMD3(left, 1.4, middle.y), size: SIMD3(wall + 0.04, 0.9, 0.3), color: whiteColor)
        ]
        for photo in 0..<3 {
            parts.append(frame.part(
                at: SIMD3(left, 1.4 + 0.27 * Float(photo - 1), middle.y), size: SIMD3(wall + 0.08, 0.2, 0.2),
                color: paleBlueColor
            ))
        }
        let signHeight = height + 0.1 + 0.2
        let signFront = middle.y + depth / 2 - 0.1
        parts.append(frame.part(
            at: SIMD3(middle.x, signHeight, signFront), size: SIMD3(width * 0.8, 0.4, 0.08), color: yellowColor
        ))
        for bulb in 0..<4 {
            let across = (Float(bulb) - 1.5) * width * 0.2
            parts.append(frame.part(
                .cylinder, at: SIMD3(middle.x + across, signHeight + 0.25, signFront), size: SIMD3(0.1, 0.1, 0.1),
                color: whiteColor
            ))
        }
        return parts
    }

    /// The cabin's front: a pleated curtain across the left half, and on the right a fixed panel with a
    /// screen, a coin slot, and a tray where the photos come out.
    private static func cabinFront(width: Float, front: Float, middle: Float, frame: Frame) -> [VenueBlock] {
        let wall = cabinWall
        let panelMiddle = middle + width / 4
        let face = front - wall / 2
        var parts = [
            frame.part(
                at: SIMD3(panelMiddle, cabinWallHeight / 2, face), size: SIMD3(width / 2, cabinWallHeight, wall),
                color: vermilionColor
            ),
            frame.part(at: SIMD3(panelMiddle, 1.45, face), size: SIMD3(0.4, 0.3, wall + 0.04), color: paleBlueColor),
            frame.part(at: SIMD3(panelMiddle, 1.1, face), size: SIMD3(0.25, 0.06, wall + 0.04), color: frameColor),
            frame.part(at: SIMD3(panelMiddle, 0.9, front + 0.04), size: SIMD3(0.3, 0.05, 0.12), color: whiteColor)
        ]
        let pleats = 4
        let pleat = (width / 2 - wall) / Float(pleats)
        for index in 0..<pleats {
            let across = middle - width / 2 + wall + pleat * (Float(index) + 0.5)
            parts.append(frame.part(
                at: SIMD3(across, 0.08 + 0.95, front - 0.06), size: SIMD3(pleat, 1.9, index % 2 == 0 ? 0.07 : 0.04),
                color: index % 2 == 0 ? cobaltColor : curtainShade
            ))
        }
        return parts
    }

    /// An open set: a backdrop between two posts, a camera on a stand facing it, a light beside the camera,
    /// and a crate of props.
    private static func photoSet(width: Float, depth: Float, middle: Float, frame: Frame) -> [VenueBlock] {
        let back = -depth / 2 + 0.2
        let stand = min(depth / 2 - 0.3, back + 1.8)
        var parts = [
            frame.part(at: SIMD3(middle, 0.08 + 1.0, back), size: SIMD3(width, 2.0, 0.06), color: coralColor),
            frame.part(at: SIMD3(middle, 0.08 + 1.3, back), size: SIMD3(width, 0.3, 0.09), color: whiteColor),
            frame.part(.cylinder, at: SIMD3(middle, 0.08 + 0.65, stand), size: SIMD3(0.05, 1.3, 0.05), color: frameColor),
            frame.part(at: SIMD3(middle, 0.08 + 1.39, stand), size: SIMD3(0.25, 0.18, 0.3), color: frameColor),
            frame.part(
                .cylinder, at: SIMD3(middle + 0.5, 0.08 + 0.85, stand), size: SIMD3(0.04, 1.7, 0.04), color: frameColor
            ),
            frame.part(at: SIMD3(middle + 0.5, 0.08 + 1.75, stand), size: SIMD3(0.35, 0.35, 0.06), color: whiteColor),
            frame.part(at: SIMD3(middle - width / 2 + 0.3, 0.08 + 0.15, back + 0.5), size: SIMD3(0.4, 0.3, 0.4), color: yellowColor)
        ]
        for side in [Float(-1), 1] {
            parts.append(frame.part(
                .cylinder, at: SIMD3(middle + side * width / 2, 0.08 + 1.1, back), size: SIMD3(0.08, 2.2, 0.08),
                color: frameColor
            ))
        }
        return parts
    }
}
