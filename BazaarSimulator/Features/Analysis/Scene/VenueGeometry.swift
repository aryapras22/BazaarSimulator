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

/// Turns a layout into the blocks the 3D view draws: floors, booths with counters and awnings, doors in
/// their frames, walls with openings, tables, and the rest.
enum VenueGeometry {
    static let floorThickness: Float = 0.1
    static let wallHeight: Float = 2.8

    // MARK: Layout

    static func blocks(for layout: Layout) -> [VenueBlock] {
        let doors = layout.objects.filter { $0.kind == .door }
        var result = floors(for: layout)
        for object in layout.objects {
            result += object.kind == .wall ? wall(object, cutBy: doors) : blocks(for: object)
        }
        return result
    }

    /// Everything one object is made of. A booth is a stall and a door is a frame with a leaf.
    static func blocks(for object: LayoutObject) -> [VenueBlock] {
        switch object.kind {
        case .booth: booth(object)
        case .door: door(object)
        default: [solid(object)]
        }
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

    // MARK: Placing parts

    /// An object's own frame: parts are placed relative to its middle, and turn with it.
    private struct Frame {
        let middle: SIMD2<Float>
        let turn: Float

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

    private static func size(of object: LayoutObject) -> (width: Float, depth: Float) {
        (Float(object.placement.sizeM.x), Float(object.placement.sizeM.y))
    }

    // MARK: Plain objects

    private static func solid(_ object: LayoutObject) -> VenueBlock {
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
        case .table: return cylinder(0.75, SIMD4(0.82, 0.75, 0.62, 1))
        case .wall: return box(wallHeight, SIMD4(0.28, 0.32, 0.40, 1))
        case .pillar: return cylinder(3.5, SIMD4(0.35, 0.38, 0.45, 1))
        case .stage: return box(0.5, SIMD4(0.52, 0.40, 0.72, 1))
        default: return box(0.15, SIMD4(0.18, 0.22, 0.30, 1))
        }
    }

    // MARK: Booths

    private static let frameColor = SIMD4<Float>(0.17, 0.19, 0.24, 1)
    private static let counterColor = SIMD4<Float>(0.93, 0.88, 0.78, 1)

    /// A stall: posts at the corners, an awning on top, a low counter along each open side, and a tall panel
    /// along each closed side, over a mat on the floor.
    private static func booth(_ object: LayoutObject) -> [VenueBlock] {
        let (width, depth) = size(of: object)
        let frame = Frame(object)
        let awning = boothColor(for: object)
        let panel = SIMD4(awning.x * 0.55, awning.y * 0.55, awning.z * 0.55, 1)
        let postSize: Float = 0.12
        let postHeight: Float = 2.3

        var parts = [
            frame.part(
                at: SIMD3(0, 0.015, 0), size: SIMD3(max(width - 0.1, 0.1), 0.03, max(depth - 0.1, 0.1)),
                color: SIMD4(0.20, 0.24, 0.32, 1)
            ),
            awningPart(of: object, frame: frame, height: postHeight + 0.05, color: awning)
        ]
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            parts.append(frame.part(
                at: SIMD3(sx * (width / 2 - postSize / 2), postHeight / 2, sz * (depth / 2 - postSize / 2)),
                size: SIMD3(postSize, postHeight, postSize), color: frameColor
            ))
        }

        // top and bottom run along the width, left and right along the depth.
        let sides: [(side: OpenSides, alongWidth: Bool, direction: Float)] = [
            (.top, true, -1), (.bottom, true, 1), (.left, false, -1), (.right, false, 1)
        ]
        for (side, alongWidth, direction) in sides {
            let length = max((alongWidth ? width : depth) - postSize * 2, 0.05)
            let reach = (alongWidth ? depth : width) / 2
            let isOpen = object.openSides.contains(side)
            let thickness: Float = isOpen ? 0.45 : 0.08
            let height: Float = isOpen ? 0.95 : 2.1
            let offset = direction * (reach - thickness / 2)
            parts.append(frame.part(
                at: alongWidth ? SIMD3(0, height / 2, offset) : SIMD3(offset, height / 2, 0),
                size: alongWidth ? SIMD3(length, height, thickness) : SIMD3(thickness, height, length),
                color: isOpen ? counterColor : panel
            ))
        }
        return parts
    }

    /// The awning stops just short of the stall's edges, so neighbors do not merge into one roof, and juts out
    /// over each open side.
    private static func awningPart(of object: LayoutObject, frame: Frame, height: Float, color: SIMD4<Float>) -> VenueBlock {
        let (width, depth) = size(of: object)
        let gap: Float = 0.04, jut: Float = 0.3
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

    private static func boothColor(for object: LayoutObject) -> SIMD4<Float> {
        let label = object.label.lowercased()
        if label.contains("food") || label.contains("f&b") || label.hasPrefix("f") {
            return SIMD4(0.95, 0.52, 0.20, 1)
        }
        return SIMD4(0.25, 0.55, 0.90, 1)
    }

    // MARK: Doors

    private static let doorFrameHeight: Float = 2.3
    private static let leafAngle: Float = 70 * .pi / 180

    /// A door: a frame of two posts and a beam, a leaf standing open, and a colored strip on the floor that
    /// shows which way people may go. A disabled door is just the frame and a gray strip.
    private static func door(_ object: LayoutObject) -> [VenueBlock] {
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
            // The leaf is hinged at one post and swung open, so the doorway reads as a doorway.
            let leafWidth = max(opening - postSize * 2, 0.2)
            let hinge = -(opening / 2 - postSize)
            let leafAlong = hinge + leafWidth / 2 * cos(leafAngle)
            let leafAcross = leafWidth / 2 * sin(leafAngle)
            parts.append(frame.part(
                at: place(leafAlong, 1.05, leafAcross),
                size: SIMD3(leafWidth, 2.1, 0.05),
                color: color,
                extraTurn: opensAlongWidth ? -leafAngle : leafAngle - .pi / 2
            ))
        }
        return parts
    }

    private static func doorColor(for object: LayoutObject) -> SIMD4<Float> {
        switch object.doorFlow?.direction {
        case .entrance: SIMD4(0.20, 0.78, 0.45, 1)
        case .exit: SIMD4(0.92, 0.30, 0.30, 1)
        case .disabled: SIMD4(0.40, 0.42, 0.47, 1)
        default: SIMD4(0.35, 0.65, 0.95, 1)
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
