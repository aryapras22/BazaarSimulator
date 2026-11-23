import Foundation
import simd

/// One solid thing in the 3D venue: a box or a cylinder with a color. Positions are layout meters, with the
/// plan's y as depth (z) and height as y.
struct VenueBlock: Equatable {
    /// A wedge is a pitched roof whose ridge runs along its width.
    enum Shape { case box, cylinder, wedge }

    var shape: Shape
    /// Center of the block.
    var center: SIMD3<Float>
    /// Width, height, and depth. A cylinder's width and depth are its diameter.
    var size: SIMD3<Float>
    /// Turn about the vertical axis, in radians, counterclockwise seen from above.
    var rotationY: Float
    var color: SIMD4<Float>
}

/// Turns a layout into the blocks the 3D view draws: floors, booths with counters and awnings, doors in
/// their frames, walls with openings, tables, and the rest.
enum VenueGeometry {
    static let floorThickness: Float = 0.1
    static let wallHeight: Float = 2.8

    // MARK: Layout

    static func blocks(for layout: Layout, legend: Legend = Legend()) -> [VenueBlock] {
        let doors = layout.objects.filter { $0.kind == .door }
        let attractions = layout.objects.filter { $0.kind == .entertainment }.map(\.placement.center)
        var result = floors(for: layout)
        for object in layout.objects {
            switch object.kind {
            case .wall:
                result += wall(object, cutBy: doors)
            case .seating:
                let nearest = attractions.min {
                    simd_distance_squared($0, object.placement.center) < simd_distance_squared($1, object.placement.center)
                }
                result += seating(object, toward: nearest)
            default:
                result += blocks(for: object, legend: legend)
            }
        }
        return result
    }

    /// The middle of every booth and attraction: the things a visitor stops to look at.
    static func attractions(in layout: Layout) -> [SIMD2<Float>] {
        layout.objects.filter { $0.kind == .booth || $0.kind == .entertainment }.map {
            SIMD2(Float($0.placement.center.x), Float($0.placement.center.y))
        }
    }

    /// Everything one object is made of. A booth is a stall, a door is a frame with leaves, tables and
    /// seating come with their chairs, and an attraction is a stage, a photobooth or a display.
    static func blocks(for object: LayoutObject, legend: Legend = Legend()) -> [VenueBlock] {
        switch object.kind {
        case .booth: booth(object, legend: legend)
        case .door: door(object)
        case .table: table(object)
        case .seating: seating(object)
        case .entertainment: entertainment(object)
        default: [solid(object)]
        }
    }

    // MARK: Floors

    private static func floors(for layout: Layout) -> [VenueBlock] {
        var result: [VenueBlock] = []
        if layout.hall.count >= 3 {
            result.append(floor(of: LayoutGeometry.bounds(of: layout.hall), color: hallFloorColor))
        } else {
            result.append(floor(
                of: BoundingBox(minX: 0, maxX: layout.sizeM.x, minY: 0, maxY: layout.sizeM.y), color: hallFloorColor
            ))
        }
        if layout.lobby.count >= 3 {
            result.append(floor(of: LayoutGeometry.bounds(of: layout.lobby), color: lobbyFloorColor))
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

    // MARK: Placing parts

    /// An object's own frame: parts are placed relative to its middle, and turn with it.
    struct Frame {
        let middle: SIMD2<Float>
        let turn: Float

        init(middle: SIMD2<Float>, turn: Float) {
            self.middle = middle
            self.turn = turn
        }

        init(_ object: LayoutObject) {
            middle = SIMD2(Float(object.placement.center.x), Float(object.placement.center.y))
            // The plan turns clockwise on screen, which is a negative turn about the vertical axis.
            turn = -Float(object.placement.rotationRadians)
        }

        /// `local` is across (x), up (y), and along the depth (z), measured from the object's middle.
        func part(
            _ shape: VenueBlock.Shape = .box,
            at local: SIMD3<Float>,
            size: SIMD3<Float>,
            color: SIMD4<Float>,
            extraTurn: Float = 0
        ) -> VenueBlock {
            let c = cos(turn), s = sin(turn)
            let x = local.x * c + local.z * s
            let z = -local.x * s + local.z * c
            return VenueBlock(
                shape: shape, center: SIMD3(middle.x + x, local.y, middle.y + z), size: size,
                rotationY: turn + extraTurn, color: color
            )
        }
    }

    static func size(of object: LayoutObject) -> (width: Float, depth: Float) {
        (Float(object.placement.sizeM.x), Float(object.placement.sizeM.y))
    }

    // MARK: Plain objects

    static let hallFloorColor = SIMD4<Float>(0.99, 0.98, 0.95, 1)
    static let lobbyFloorColor = SIMD4<Float>(0.94, 0.80, 0.33, 1)
    static let blockColor = SIMD4<Float>(0.56, 0.63, 0.82, 1)
    static let frameColor = SIMD4<Float>(0.11, 0.15, 0.34, 1)
    static let creamColor = SIMD4<Float>(0.99, 0.97, 0.92, 1)
    static let whiteColor = SIMD4<Float>(1, 1, 1, 1)
    static let cobaltColor = SIMD4<Float>(0.20, 0.38, 0.75, 1)
    static let vermilionColor = SIMD4<Float>(0.92, 0.33, 0.16, 1)
    static let yellowColor = SIMD4<Float>(0.94, 0.78, 0.25, 1)
    static let coralColor = SIMD4<Float>(0.96, 0.60, 0.50, 1)
    static let paleBlueColor = SIMD4<Float>(0.80, 0.85, 0.94, 1)

    static func entertainmentColor(for object: LayoutObject) -> SIMD4<Float> {
        switch EntertainmentType.resolve(catalogID: object.catalogID, label: object.label) {
        case .photobooth: vermilionColor
        case .stage, .other, .informationDesk, .disabled: coralColor
        }
    }

    static func solid(_ object: LayoutObject) -> VenueBlock {
        let (width, depth) = size(of: object)
        let frame = Frame(object)

        func box(_ height: Float, _ color: SIMD4<Float>) -> VenueBlock {
            frame.part(at: SIMD3(0, height / 2, 0), size: SIMD3(width, height, depth), color: color)
        }
        func cylinder(_ height: Float, _ color: SIMD4<Float>) -> VenueBlock {
            let diameter = min(width, depth)
            return frame.part(.cylinder, at: SIMD3(0, height / 2, 0), size: SIMD3(diameter, height, diameter), color: color)
        }

        switch object.kind {
        case .wall: return box(wallHeight, whiteColor)
        case .block where object.isColumn: return cylinder(Float(object.heightM ?? 3.5), cobaltColor)
        case .block: return box(Float(object.heightM ?? 0.8), blockColor)
        default: return box(0.15, paleBlueColor)
        }
    }

    // MARK: Walls with openings

    /// A wall, with a gap wherever a door stands in it. Only walls that run straight along the plan's axes
    /// are cut; anything turned at another angle stays whole.
    private static func wall(_ wall: LayoutObject, cutBy doors: [LayoutObject]) -> [VenueBlock] {
        let whole = solid(wall)
        guard wall.placement.rotationDegrees % 90 == 0 else { return [whole] }

        let box = LayoutGeometry.bounds(of: wall.placement)
        let runsAlongX = box.maxX - box.minX >= box.maxY - box.minY
        let wallRange = runsAlongX ? (box.minX, box.maxX) : (box.minY, box.maxY)
        let wallAcross = runsAlongX ? (box.minY, box.maxY) : (box.minX, box.maxX)

        var gaps: [(Double, Double)] = []
        for door in doors where door.doorFlow?.direction != .disabled {
            let doorBox = LayoutGeometry.bounds(of: door.placement)
            let doorRunsAlongX = doorBox.maxX - doorBox.minX >= doorBox.maxY - doorBox.minY
            let doorRange = runsAlongX ? (doorBox.minX, doorBox.maxX) : (doorBox.minY, doorBox.maxY)
            let doorAcross = runsAlongX ? (doorBox.minY, doorBox.maxY) : (doorBox.minX, doorBox.maxX)
            guard doorRunsAlongX == runsAlongX,
                  doorAcross.0 < wallAcross.1 + 0.05, doorAcross.1 > wallAcross.0 - 0.05,
                  doorRange.0 < wallRange.1, doorRange.1 > wallRange.0 else { continue }
            gaps.append((max(doorRange.0, wallRange.0), min(doorRange.1, wallRange.1)))
        }
        guard !gaps.isEmpty else { return [whole] }

        // Merge gaps that touch, then keep what is left between them.
        var merged: [(Double, Double)] = []
        for gap in gaps.sorted(by: { $0.0 < $1.0 }) {
            if let last = merged.last, gap.0 <= last.1 {
                merged[merged.count - 1].1 = max(last.1, gap.1)
            } else {
                merged.append(gap)
            }
        }
        var pieces: [(Double, Double)] = []
        var cursor = wallRange.0
        for gap in merged {
            if gap.0 - cursor > 0.05 { pieces.append((cursor, gap.0)) }
            cursor = gap.1
        }
        if wallRange.1 - cursor > 0.05 { pieces.append((cursor, wallRange.1)) }

        return pieces.map { piece in
            let along = Float(piece.1 - piece.0), middle = Float((piece.0 + piece.1) / 2)
            let across = Float(wallAcross.1 - wallAcross.0), acrossMiddle = Float((wallAcross.0 + wallAcross.1) / 2)
            return VenueBlock(
                shape: .box,
                center: runsAlongX ? SIMD3(middle, wallHeight / 2, acrossMiddle) : SIMD3(acrossMiddle, wallHeight / 2, middle),
                size: runsAlongX ? SIMD3(along, wallHeight, across) : SIMD3(across, wallHeight, along),
                rotationY: 0,
                color: whole.color
            )
        }
    }
}
