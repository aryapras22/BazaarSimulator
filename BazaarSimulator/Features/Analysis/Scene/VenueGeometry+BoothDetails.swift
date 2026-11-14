import Foundation
import simd

extension VenueGeometry {
    private static let roofRise: Float = 0.55

    /// What makes a stall look like a stall from a distance: a pitched roof over the awning, a signboard
    /// above the first open side, and a shelf of stock against the first closed side.
    static func boothDetails(of object: LayoutObject, awning: VenueBlock, frame: Frame) -> [VenueBlock] {
        let (width, depth) = size(of: object)
        let sides: [(side: OpenSides, alongWidth: Bool, direction: Float)] = [
            (.bottom, true, 1), (.top, true, -1), (.right, false, 1), (.left, false, -1)
        ]
        let front = sides.first { object.openSides.contains($0.side) }
        let back = sides.first { !object.openSides.contains($0.side) }

        // The ridge runs along the front, so a slope faces the customers.
        var roof = awning
        roof.shape = .wedge
        roof.center.y = awning.center.y + awning.size.y / 2 + roofRise / 2
        roof.size.y = roofRise
        if let front, !front.alongWidth {
            roof.rotationY += .pi / 2
            roof.size = SIMD3(awning.size.z, roofRise, awning.size.x)
        }
        var parts = [roof]

        /// Places a part on one side by how far along the side it is and how far out from the stall's middle.
        func part(
            on side: (side: OpenSides, alongWidth: Bool, direction: Float), _ shape: VenueBlock.Shape = .box,
            along: Float, height: Float, out: Float, size: SIMD3<Float>, color: SIMD4<Float>
        ) -> VenueBlock {
            let place = side.alongWidth
                ? SIMD3(along, height, side.direction * out) : SIMD3(side.direction * out, height, along)
            let sized = side.alongWidth ? size : SIMD3(size.z, size.y, size.x)
            return frame.part(shape, at: place, size: sized, color: color)
        }

        if let front {
            let length = (front.alongWidth ? width : depth) - 0.24
            let out = (front.alongWidth ? depth : width) / 2 + 0.18
            let height = awning.center.y + awning.size.y / 2 + 0.2
            parts += [
                part(on: front, along: 0, height: height, out: out, size: SIMD3(length * 0.55, 0.4, 0.05), color: whiteColor),
                part(on: front, along: 0, height: height, out: out, size: SIMD3(length * 0.42, 0.2, 0.08), color: yellowColor)
            ]
        }
        if let back {
            let length = ((back.alongWidth ? width : depth) - 0.24) * 0.8
            let out = (back.alongWidth ? depth : width) / 2 - 0.08 - 0.16
            parts.append(part(on: back, along: 0, height: 1.2, out: out, size: SIMD3(length, 0.04, 0.3), color: creamColor))
            let colors = [yellowColor, coralColor, paleBlueColor, whiteColor]
            let count = min(max(Int(length / 0.6), 1), 4)
            for index in 0..<count {
                let along = (Float(index) - Float(count - 1) / 2) * length / Float(count)
                parts.append(part(
                    on: back, along: along, height: 1.22 + 0.15, out: out, size: SIMD3(0.3, 0.3, 0.22),
                    color: colors[index % colors.count]
                ))
            }
        }
        return parts
    }
}
