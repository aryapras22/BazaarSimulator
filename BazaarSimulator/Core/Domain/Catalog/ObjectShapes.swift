import Foundation
import simd

enum ObjectShapes {
    static func shape(for id: String, size: SIMD2<Double>, height: Double) -> [ShapePrimitive] {
        if let shape = structureShape(for: id, size: size, height: height) {
            return shape
        }
        if let model = FurnitureModels.table(id) {
            return tableShape(model, size: size, height: height)
        }
        if id == FurnitureModels.seatingBlockID {
            return seatingShape(size: size)
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
        case "block":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .slab)]
        case "door":
            return openingShape(size: size, height: height)
        case "blocked-area":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .slab)]
        default:
            return nil
        }
    }

    private static func tableShape(_ model: TableModel, size: SIMD2<Double>, height: Double) -> [ShapePrimitive] {
        let topThickness = 0.04
        let top: ShapePrimitive
        switch model.shape {
        case .round:
            top = .cylinder(
                center: SIMD3(0, height - topThickness / 2, 0), radii: SIMD2(repeating: size.x / 2),
                height: topThickness, yaw: 0, segments: 24, role: .tabletop
            )
        case .rect:
            top = Shapes.box(
                center: SIMD3(0, height - topThickness / 2, 0),
                size: SIMD3(size.x, topThickness, size.y),
                role: .tabletop
            )
        }
        let pedestal = Shapes.box(
            center: SIMD3(0, (height - topThickness) / 2, 0),
            size: SIMD3(0.1, height - topThickness, 0.1),
            role: .frame
        )
        return [top, pedestal] + FurnitureModels.seatOffsets(of: model).map(chairShape)
    }

    private static func seatingShape(size: SIMD2<Double>) -> [ShapePrimitive] {
        FurnitureModels.gridOffsets(for: size).map(chairShape)
    }

    private static func chairShape(at offset: SIMD2<Double>) -> ShapePrimitive {
        Shapes.box(
            center: SIMD3(offset.x, FurnitureModels.chairHeightM / 2, offset.y),
            size: SIMD3(FurnitureModels.chairSizeM.x, FurnitureModels.chairHeightM, FurnitureModels.chairSizeM.y),
            role: .fabric
        )
    }

    private static func openingShape(size: SIMD2<Double>, height: Double) -> [ShapePrimitive] {
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

        let leaf = Shapes.box(
            center: SIMD3(0, doorH / 2.0, 0),
            size: SIMD3(innerW, doorH, thickness), role: .accent
        )
        return [leftPost, rightPost, lintel, leaf]
    }
}
