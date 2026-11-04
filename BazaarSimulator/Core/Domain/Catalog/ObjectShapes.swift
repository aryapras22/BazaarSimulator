import Foundation
import simd

enum ObjectShapes {
    static func shape(for id: String, size: SIMD2<Double>, height: Double) -> [ShapePrimitive] {
        if let shape = structureShape(for: id, size: size, height: height) {
            return shape
        }
        if let shape = furnitureShape(for: id, size: size, height: height) {
            return shape
        }
        if let shape = decorShape(for: id, size: size, height: height) {
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
        case "rail":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .frame)]
        case "block":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .slab)]
        case "pillar-round":
            return [.cylinder(
                center: SIMD3(0, height / 2.0, 0), radius: size.x / 2.0,
                height: height, segments: 16, role: .pillar
            )]
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

    private static func furnitureShape(
        for id: String,
        size: SIMD2<Double>,
        height: Double
    ) -> [ShapePrimitive]? {
        switch id {
        case "table-round-4", "table-round-6", "table-round-8", "table-bar":
            let topRadius = size.x / 2.0
            let topH = min(0.04, height * 0.1)
            let legH = max(0, height - topH)
            let top = ShapePrimitive.cylinder(
                center: SIMD3(0, height - topH / 2.0, 0),
                radius: topRadius,
                height: topH,
                segments: id == "table-bar" ? 16 : 20,
                role: .tabletop
            )
            return [top] + Shapes.pedestal(height: legH, topRadius: topRadius, role: .frame)
        case "table-rect-6ft":
            let topH = min(0.04, height * 0.1)
            let legH = max(0, height - topH)
            let top = Shapes.box(
                center: SIMD3(0, height - topH / 2.0, 0),
                size: SIMD3(size.x, topH, size.y), role: .tabletop
            )
            return [top] + Shapes.legs(width: size.x, depth: size.y, height: legH, role: .frame)
        case "bench":
            let seatH = min(0.05, height * 0.2)
            let legH = max(0, height - seatH)
            let seat = Shapes.box(
                center: SIMD3(0, height - seatH / 2.0, 0),
                size: SIMD3(size.x, seatH, size.y), role: .tabletop
            )
            return [seat] + Shapes.legs(width: size.x, depth: size.y, height: legH, role: .frame, thickness: 0.04)
        case "stage", "stage-extension":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .stage)]
        case "counter":
            return [Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .counter)]
        case "kiosk":
            let body = Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .frame)
            let screenH = height * 0.3
            let screen = Shapes.box(
                center: SIMD3(0, height * 0.75, size.y / 2.0 - 0.01),
                size: SIMD3(size.x * 0.8, screenH, 0.02), role: .sign
            )
            return [body, screen]
        default:
            return nil
        }
    }

    private static func decorShape(
        for id: String,
        size: SIMD2<Double>,
        height: Double
    ) -> [ShapePrimitive]? {
        switch id {
        case "planter":
            let potH = height * 0.6
            let plantH = height - potH
            let pot = Shapes.box(center: SIMD3(0, potH / 2.0, 0), size: SIMD3(size.x, potH, size.y), role: .frame)
            let plant = Shapes.box(
                center: SIMD3(0, potH + plantH / 2.0, 0),
                size: SIMD3(size.x * 0.85, plantH, size.y * 0.85), role: .plant
            )
            return [pot, plant]
        case "floor-sign", "banner-stand":
            return signageShape(for: id, size: size, height: height)
        case "bin":
            return [.cylinder(
                center: SIMD3(0, height / 2.0, 0), radius: size.x / 2.0,
                height: height, segments: 12, role: .frame
            )]
        case "display-case", "claw-machine", "photo-booth":
            return exhibitShape(for: id, size: size, height: height)
        default:
            return nil
        }
    }

    private static func signageShape(
        for id: String,
        size: SIMD2<Double>,
        height: Double
    ) -> [ShapePrimitive] {
        if id == "floor-sign" {
            let baseH = min(0.03, height * 0.05)
            let signH = min(0.5, height * 0.4)
            let poleH = height - signH
            let base = Shapes.box(
                center: SIMD3(0, baseH / 2.0, 0),
                size: SIMD3(size.x * 0.8, baseH, size.y * 0.8), role: .frame
            )
            let pole = ShapePrimitive.cylinder(
                center: SIMD3(0, poleH / 2.0, 0), radius: 0.02, height: poleH, segments: 8, role: .frame
            )
            let sign = Shapes.box(
                center: SIMD3(0, height - signH / 2.0, 0),
                size: SIMD3(size.x, signH, min(0.02, size.y)), role: .sign
            )
            return [base, pole, sign]
        } else {
            let baseH = min(0.04, height * 0.05)
            let bannerH = height - baseH
            let base = Shapes.box(
                center: SIMD3(0, baseH / 2.0, 0),
                size: SIMD3(size.x, baseH, size.y), role: .frame
            )
            let banner = Shapes.box(
                center: SIMD3(0, baseH + bannerH / 2.0, 0),
                size: SIMD3(size.x * 0.95, bannerH, min(0.02, size.y)), role: .fabric
            )
            return [base, banner]
        }
    }

    private static func exhibitShape(
        for id: String,
        size: SIMD2<Double>,
        height: Double
    ) -> [ShapePrimitive] {
        switch id {
        case "display-case":
            let baseH = height * 0.4
            let glassH = height - baseH
            let base = Shapes.box(center: SIMD3(0, baseH / 2.0, 0), size: SIMD3(size.x, baseH, size.y), role: .frame)
            let glass = Shapes.box(
                center: SIMD3(0, baseH + glassH / 2.0, 0),
                size: SIMD3(size.x, glassH, size.y), role: .glass
            )
            return [base, glass]
        case "claw-machine":
            let baseH = height * 0.45
            let glassH = height * 0.45
            let topH = height - baseH - glassH
            let base = Shapes.box(center: SIMD3(0, baseH / 2.0, 0), size: SIMD3(size.x, baseH, size.y), role: .frame)
            let glass = Shapes.box(
                center: SIMD3(0, baseH + glassH / 2.0, 0),
                size: SIMD3(size.x, glassH, size.y), role: .glass
            )
            let top = Shapes.box(
                center: SIMD3(0, height - topH / 2.0, 0),
                size: SIMD3(size.x, topH, size.y), role: .sign
            )
            return [base, glass, top]
        default: // photo-booth
            let body = Shapes.box(center: SIMD3(0, height / 2.0, 0), size: SIMD3(size.x, height, size.y), role: .frame)
            let curtainH = height * 0.8
            let curtain = Shapes.box(
                center: SIMD3(-size.x * 0.2, curtainH / 2.0, size.y / 2.0 - 0.01),
                size: SIMD3(size.x * 0.4, curtainH, 0.02), role: .fabric
            )
            return [body, curtain]
        }
    }
}
