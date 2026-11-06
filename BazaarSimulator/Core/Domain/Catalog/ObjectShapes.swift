import Foundation
import simd

enum ObjectShapes {
    static func shape(for id: String, size: SIMD2<Double>, height: Double) -> [ShapePrimitive] {
        if let shape = structureShape(for: id, size: size, height: height) {
            return shape
        }
        return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .frame)]
    }

    private static func structureShape(
        for id: String,
        size: SIMD2<Double>,
        height: Double
    ) -> [ShapePrimitive]? {
        switch id {
        case "wall":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .wall)]
        case "partition":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .wall)]
        case "block":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .slab)]
        case "door", "double-door", "gate":
            return openingShape(size: size, height: height, isDouble: id != "door")
        case "blocked-area":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .slab)]
        default:
            return nil
        }
    }

    private static func openingShape(size: SIMD2<Double>, height: Double, isDouble: Bool) -> [ShapePrimitive] {
        let postW = min(0.08, size.x * 0.1)
        let lintelH = min(0.2, height * 0.1)
        let doorH = max(0, height - lintelH)
        let leftPost = Shapes.box(
            center: SIMD3(-size.x / 2.0 + postW / 2.0, height / 2.0, 0),
            size: SIMD3(postW, height, size.y), role: .frame
        )
        let rightPost = Shapes.box(
            center: SIMD3(size.x / 2.0 - postW / 2.0, height / 2.0, 0),
            size: SIMD3(postW, height, size.y), role: .frame
        )
        let lintel = Shapes.box(
            center: SIMD3(0, height - lintelH / 2.0, 0),
            size: SIMD3(size.x, lintelH, size.y), role: .wall
        )
        let innerW = max(0, size.x - 2.0 * postW)
        let thickness = min(0.04, size.y)

        if isDouble {
            let leafW = innerW / 2.0
            let leaf1 = Shapes.box(
                center: SIMD3(-leafW / 2.0, doorH / 2.0, 0),
                size: SIMD3(leafW, doorH, thickness), role: .accent
            )
            let leaf2 = Shapes.box(
                center: SIMD3(leafW / 2.0, doorH / 2.0, 0),
                size: SIMD3(leafW, doorH, thickness), role: .accent
            )
            return [leftPost, rightPost, lintel, leaf1, leaf2]
        } else {
            let leaf = Shapes.box(
                center: SIMD3(0, doorH / 2.0, 0),
                size: SIMD3(innerW, doorH, thickness), role: .accent
            )
            return [leftPost, rightPost, lintel, leaf]
        }
    }
}
