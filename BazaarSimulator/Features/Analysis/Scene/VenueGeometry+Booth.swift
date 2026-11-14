import Foundation
import simd

extension VenueGeometry {
    // MARK: Booths

    private static let boothPostSize: Float = 0.12
    private static let boothPostHeight: Float = 2.3
    private static let awningJut: Float = 0.3
    /// Top and bottom run along the width, left and right along the depth.
    private static let boothSides: [(side: OpenSides, alongWidth: Bool, direction: Float)] = [
        (.top, true, -1), (.bottom, true, 1), (.left, false, -1), (.right, false, 1)
    ]

    /// A stall: posts at the corners, an awning on top, a low counter along each open side, and a tall panel
    /// along each closed side, over a mat on the floor. Each open side also has a striped valance hanging
    /// from the awning and goods laid out on the counter.
    static func booth(_ object: LayoutObject) -> [VenueBlock] {
        let (width, depth) = size(of: object)
        let frame = Frame(object)
        let awning = boothColor(for: object)
        let panel = SIMD4(awning.x * 0.55, awning.y * 0.55, awning.z * 0.55, 1)
        let postSize = boothPostSize
        let postHeight = boothPostHeight
        let isFood = awning == vermilionColor

        var parts = [
            frame.part(
                at: SIMD3(0, 0.015, 0), size: SIMD3(max(width - 0.1, 0.1), 0.03, max(depth - 0.1, 0.1)),
                color: SIMD4(0.84, 0.88, 0.95, 1)
            ),
            awningPart(of: object, frame: frame, height: postHeight + 0.05, color: awning)
        ]
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            parts.append(frame.part(
                at: SIMD3(sx * (width / 2 - postSize / 2), postHeight / 2, sz * (depth / 2 - postSize / 2)),
                size: SIMD3(postSize, postHeight, postSize), color: frameColor
            ))
        }

        for (side, alongWidth, direction) in boothSides {
            let length = max((alongWidth ? width : depth) - postSize * 2, 0.05)
            let reach = (alongWidth ? depth : width) / 2
            let isOpen = object.openSides.contains(side)
            let thickness: Float = isOpen ? 0.45 : 0.08
            let height: Float = isOpen ? 0.95 : 2.1
            let offset = direction * (reach - thickness / 2)
            parts.append(frame.part(
                at: alongWidth ? SIMD3(0, height / 2, offset) : SIMD3(offset, height / 2, 0),
                size: alongWidth ? SIMD3(length, height, thickness) : SIMD3(thickness, height, length),
                color: isOpen ? creamColor : panel
            ))
        }
        for (side, alongWidth, direction) in boothSides where object.openSides.contains(side) {
            let length = max((alongWidth ? width : depth) - postSize * 2, 0.05)
            let reach = (alongWidth ? depth : width) / 2
            /// Places a part by how far along the side it is and how far out from the stall's middle.
            func place(_ along: Float, _ height: Float, _ out: Float) -> SIMD3<Float> {
                alongWidth ? SIMD3(along, height, direction * out) : SIMD3(direction * out, height, along)
            }
            func sized(_ along: Float, _ height: Float, _ across: Float) -> SIMD3<Float> {
                alongWidth ? SIMD3(along, height, across) : SIMD3(across, height, along)
            }
            parts += valance(length: length, out: reach + awningJut - 0.12, color: awning) { along, height, out, size in
                frame.part(at: place(along, height, out), size: sized(size.x, size.y, size.z), color: size.w > 0 ? awning : whiteColor)
            }
            parts += goods(isFood: isFood, length: length, out: reach - 0.225) { shape, along, height, out, size, color in
                frame.part(shape, at: place(along, height, out), size: sized(size.x, size.y, size.z), color: color)
            }
        }
        return parts + boothDetails(of: object, awning: parts[1], frame: frame)
    }

    /// A band hanging from the awning's edge, in stripes of the awning's color and white. The fourth number
    /// of each size is 1 for a colored stripe and 0 for a white one.
    private static func valance(
        length: Float, out: Float, color: SIMD4<Float>,
        make: (_ along: Float, _ height: Float, _ out: Float, _ size: SIMD4<Float>) -> VenueBlock
    ) -> [VenueBlock] {
        let stripes = max(2, Int((length / 0.45).rounded()))
        let stripe = length / Float(stripes)
        return (0..<stripes).map { index in
            let along = (Float(index) - Float(stripes - 1) / 2) * stripe
            return make(along, boothPostHeight - 0.14, out, SIMD4(stripe, 0.28, 0.03, index % 2 == 0 ? 1 : 0))
        }
    }

    /// A few things on a counter, spaced along it: pots and jars at a food stall, boxes anywhere else.
    private static func goods(
        isFood: Bool, length: Float, out: Float,
        make: (VenueBlock.Shape, _ along: Float, _ height: Float, _ out: Float, _ size: SIMD3<Float>, SIMD4<Float>) -> VenueBlock
    ) -> [VenueBlock] {
        let kinds: [(shape: VenueBlock.Shape, size: SIMD3<Float>, color: SIMD4<Float>)] = isFood ? [
            (.cylinder, SIMD3(0.34, 0.2, 0.34), frameColor),
            (.cylinder, SIMD3(0.16, 0.28, 0.16), yellowColor),
            (.cylinder, SIMD3(0.26, 0.14, 0.26), whiteColor)
        ] : [
            (.box, SIMD3(0.30, 0.18, 0.24), yellowColor),
            (.box, SIMD3(0.20, 0.30, 0.20), coralColor),
            (.box, SIMD3(0.24, 0.12, 0.24), paleBlueColor)
        ]
        let count = min(max(Int(length / 0.9), 1), 5)
        let spacing = length / Float(count)
        return (0..<count).map { index in
            let kind = kinds[index % kinds.count]
            let along = (Float(index) - Float(count - 1) / 2) * spacing
            return make(kind.shape, along, 0.95 + kind.size.y / 2, out, kind.size, kind.color)
        }
    }

    /// The awning stops just short of the stall's edges, so neighbors do not merge into one roof, and juts out
    /// over each open side.
    static func awningPart(of object: LayoutObject, frame: Frame, height: Float, color: SIMD4<Float>) -> VenueBlock {
        let (width, depth) = size(of: object)
        let gap: Float = 0.04, jut = awningJut
        var low = SIMD2(-width / 2 + gap, -depth / 2 + gap)
        var high = SIMD2(width / 2 - gap, depth / 2 - gap)
        if object.openSides.contains(.left) { low.x -= jut + gap }
        if object.openSides.contains(.right) { high.x += jut + gap }
        if object.openSides.contains(.top) { low.y -= jut + gap }
        if object.openSides.contains(.bottom) { high.y += jut + gap }
        return frame.part(
            at: SIMD3((low.x + high.x) / 2, height, (low.y + high.y) / 2),
            size: SIMD3(max(high.x - low.x, 0.1), 0.1, max(high.y - low.y, 0.1)),
            color: color
        )
    }

    static func boothColor(for object: LayoutObject) -> SIMD4<Float> {
        let label = object.label.lowercased()
        if label.contains("food") || label.contains("f&b") || label.hasPrefix("f") {
            return vermilionColor
        }
        return cobaltColor
    }
}
