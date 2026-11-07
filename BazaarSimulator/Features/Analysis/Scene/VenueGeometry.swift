import Foundation
import simd

/// One solid thing in the 3D venue: a box or a cylinder with a color. Positions are layout meters, with the
/// plan's y as depth (z) and height as y.
struct VenueBlock: Equatable {
    enum Shape { case box, cylinder }

    var shape: Shape
    /// Center of the block.
    var center: SIMD3<Float>
    /// Width, height, and depth. A cylinder's width and depth are its diameter.
    var size: SIMD3<Float>
    /// Turn about the vertical axis, in radians, counterclockwise seen from above.
    var rotationY: Float
    var color: SIMD4<Float>
}

/// Turns a layout into the blocks the 3D view draws: floors, booths, tables, walls, doors, and the rest.
enum VenueGeometry {
    static let floorThickness: Float = 0.1

    static func blocks(for layout: Layout) -> [VenueBlock] {
        floors(for: layout) + layout.objects.map(block(for:))
    }

    // MARK: Floors

    private static func floors(for layout: Layout) -> [VenueBlock] {
        var result: [VenueBlock] = []
        let hallColor = SIMD4<Float>(0.11, 0.14, 0.22, 1)
        let lobbyColor = SIMD4<Float>(0.09, 0.12, 0.18, 1)
        if layout.hall.count >= 3 {
            result.append(floor(of: LayoutGeometry.bounds(of: layout.hall), color: hallColor))
        } else {
            result.append(floor(
                of: BoundingBox(minX: 0, maxX: layout.sizeM.x, minY: 0, maxY: layout.sizeM.y), color: hallColor
            ))
        }
        if layout.lobby.count >= 3 {
            result.append(floor(of: LayoutGeometry.bounds(of: layout.lobby), color: lobbyColor))
        }
        return result
    }

    private static func floor(of box: BoundingBox, color: SIMD4<Float>) -> VenueBlock {
        VenueBlock(
            shape: .box,
            center: SIMD3(Float(box.minX + box.maxX) / 2, -floorThickness / 2, Float(box.minY + box.maxY) / 2),
            size: SIMD3(Float(box.maxX - box.minX), floorThickness, Float(box.maxY - box.minY)),
            rotationY: 0,
            color: color
        )
    }

    // MARK: Objects

    static func block(for object: LayoutObject) -> VenueBlock {
        let width = Float(object.placement.sizeM.x)
        let depth = Float(object.placement.sizeM.y)
        let middle = SIMD2(Float(object.placement.center.x), Float(object.placement.center.y))
        // The plan turns clockwise on screen, which is a negative turn about the vertical axis.
        let turn = -Float(object.placement.rotationRadians)

        func box(_ height: Float, _ color: SIMD4<Float>, depth: Float? = nil) -> VenueBlock {
            VenueBlock(shape: .box, center: SIMD3(middle.x, height / 2, middle.y),
                       size: SIMD3(width, height, depth ?? Self.depth(of: object)), rotationY: turn, color: color)
        }
        func cylinder(_ height: Float, _ color: SIMD4<Float>) -> VenueBlock {
            let diameter = min(width, depth)
            return VenueBlock(shape: .cylinder, center: SIMD3(middle.x, height / 2, middle.y),
                              size: SIMD3(diameter, height, diameter), rotationY: turn, color: color)
        }

        switch object.kind {
        case .booth: return box(2.2, boothColor(for: object))
        case .table: return cylinder(0.75, SIMD4(0.82, 0.75, 0.62, 1))
        case .wall: return box(2.8, SIMD4(0.28, 0.32, 0.40, 1))
        case .door: return box(0.04, doorColor(for: object), depth: max(depth, 0.5))
        case .pillar: return cylinder(3.5, SIMD4(0.35, 0.38, 0.45, 1))
        case .stage: return box(0.5, SIMD4(0.52, 0.40, 0.72, 1))
        case .closedArea, .block, .fixture, .rail, .audienceArea: return box(0.15, SIMD4(0.18, 0.22, 0.30, 1))
        }
    }

    private static func depth(of object: LayoutObject) -> Float {
        Float(object.placement.sizeM.y)
    }

    private static func boothColor(for object: LayoutObject) -> SIMD4<Float> {
        let label = object.label.lowercased()
        if label.contains("food") || label.contains("f&b") || label.hasPrefix("f") {
            return SIMD4(0.95, 0.52, 0.20, 1)
        }
        return SIMD4(0.25, 0.55, 0.90, 1)
    }

    private static func doorColor(for object: LayoutObject) -> SIMD4<Float> {
        switch object.doorFlow?.direction {
        case .entrance: SIMD4(0.20, 0.78, 0.45, 1)
        case .exit: SIMD4(0.92, 0.30, 0.30, 1)
        default: SIMD4(0.35, 0.65, 0.95, 1)
        }
    }
}
