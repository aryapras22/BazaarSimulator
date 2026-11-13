import simd
import Testing
@testable import BazaarSimulator

@Suite
struct MeshDataTests {
    private func triangles(_ mesh: MeshData) -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        stride(from: 0, to: mesh.indices.count, by: 3).map {
            (mesh.vertices[Int(mesh.indices[$0])].position, mesh.vertices[Int(mesh.indices[$0 + 1])].position,
             mesh.vertices[Int(mesh.indices[$0 + 2])].position)
        }
    }

    private func allFaceOutward(_ mesh: MeshData) -> Bool {
        triangles(mesh).allSatisfy { a, b, c in
            let facing = simd_cross(b - a, c - a)
            let middle = (a + b + c) / 3
            // Shapes centered on the origin: a face turned outward points away from the middle.
            return simd_dot(facing, middle) >= -1e-5
        }
    }

    @Test("A cube has six faces of two triangles, all turned outward")
    func cube() {
        let mesh = MeshData.cube
        #expect(mesh.vertices.count == 24 && mesh.indices.count == 36)
        #expect(allFaceOutward(mesh))
        #expect(mesh.vertices.allSatisfy { $0.position.x.magnitude == 0.5 || $0.position.y.magnitude == 0.5 || $0.position.z.magnitude == 0.5 })
    }

    @Test("A cylinder is one unit tall and across, with every face turned outward")
    func cylinder() {
        let mesh = MeshData.cylinder
        #expect(allFaceOutward(mesh))
        #expect(mesh.vertices.map(\.position.y).max() == 0.5 && mesh.vertices.map(\.position.y).min() == -0.5)
        #expect(mesh.vertices.allSatisfy { hypot($0.position.x, $0.position.z) <= 0.5 + 1e-5 })
    }

    @Test("A capsule has the height and width asked for, with every face turned outward")
    func capsule() {
        let mesh = MeshData.capsule(radius: 0.28, height: 1.7)
        #expect(allFaceOutward(mesh))
        #expect(abs((mesh.vertices.map(\.position.y).max() ?? 0) - 0.85) < 1e-4)
        #expect(abs((mesh.vertices.map(\.position.y).min() ?? 0) + 0.85) < 1e-4)
        #expect(mesh.vertices.allSatisfy { hypot($0.position.x, $0.position.z) <= 0.28 + 1e-4 })
    }

    @Test("Every triangle points at corners that exist, and normals are unit length")
    func wellFormed() {
        for mesh in [MeshData.cube, .cylinder, .capsule(radius: 0.3, height: 1.8)] {
            #expect(mesh.indices.count % 3 == 0)
            #expect(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count })
            #expect(mesh.vertices.allSatisfy { abs(simd_length($0.normal) - 1) < 1e-4 })
        }
    }
}

@Suite
struct VenueGeometryTests {
    private func object(
        _ kind: LayoutObjectKind,
        label: String = "X1",
        center: SIMD2<Double> = SIMD2(10, 6),
        size: SIMD2<Double> = SIMD2(4, 2),
        rotation: Double = 0,
        open: OpenSides = [],
        flow: DoorFlow? = nil,
        catalogID: String? = nil
    ) -> LayoutObject {
        LayoutObject(
            kind: kind, label: label,
            placement: Placement(center: center, sizeM: size, rotationRadians: rotation),
            openSides: open, doorFlow: flow, catalogID: catalogID
        )
    }

    /// Where a block is, measured from its object's middle along the object's own width and depth.
    private func local(_ block: VenueBlock, in object: LayoutObject) -> SIMD3<Float> {
        let turn = -Float(object.placement.rotationRadians)
        let dx = block.center.x - Float(object.placement.center.x)
        let dz = block.center.z - Float(object.placement.center.y)
        return SIMD3(dx * cos(turn) - dz * sin(turn), block.center.y, dx * sin(turn) + dz * cos(turn))
    }

    private func top(_ block: VenueBlock) -> Float { block.center.y + block.size.y / 2 }

    // MARK: Plain objects

    @Test("A round table is a top on a pedestal with a chair at each seat, turned to face it")
    func roundTable() {
        let table = object(.table, size: SIMD2(1.5, 1.5), catalogID: "table-round-6")
        let parts = VenueGeometry.blocks(for: table)
        #expect(parts.count == 3 + 6 * 6)
        #expect(parts[0].shape == .cylinder && parts[0].size.x == 1.5 && abs(top(parts[0]) - 0.75) < 0.001)
        let backs = parts.filter { $0.size.y == 0.4 }
        #expect(backs.count == 6)
        let seats = parts.filter { $0.size == SIMD3(0.4, 0.05, 0.4) }
        for (seat, back) in zip(seats, backs) {
            let fromTable = simd_length(SIMD2(seat.center.x - 10, seat.center.z - 6))
            #expect(simd_length(SIMD2(back.center.x - 10, back.center.z - 6)) > fromTable, "the back is on the far side")
        }
    }

    @Test("A rectangular table stands on four legs, and a table of no known model has no chairs")
    func rectTable() {
        let parts = VenueGeometry.blocks(for: object(.table, size: SIMD2(1.2, 0.7), catalogID: "table-rect-4"))
        #expect(parts.count == 5 + 4 * 6)
        #expect(parts[0].shape == .box && parts[0].size.x == 1.2)
        #expect(VenueGeometry.blocks(for: object(.table)).count == 5)
    }

    @Test("Seating is rows of chairs on a mat, turned toward the stage they are given")
    func seating() {
        let block = object(.seating, size: SIMD2(2, 1))
        let plain = VenueGeometry.blocks(for: block)
        #expect(plain.count == 1 + 8 * 6)
        func backSide(_ parts: [VenueBlock]) -> SIMD2<Float> {
            let seat = parts.first { $0.size == SIMD3(0.4, 0.05, 0.4) }!
            let back = parts.first { $0.size.y == 0.4 }!
            return simd_normalize(SIMD2(back.center.x - seat.center.x, back.center.z - seat.center.z))
        }
        #expect(backSide(plain).y > 0.99, "with no stage the chairs face the top of the plan")
        let towardRight = VenueGeometry.seating(block, toward: SIMD2(30, 6))
        #expect(backSide(towardRight).x < -0.99, "the backs are away from the stage")
    }

    @Test("A stage has a deck, a backdrop and truss at the back, and steps at its open side")
    func stage() {
        let stage = object(.entertainment, label: "Stage", open: [.top])
        let parts = VenueGeometry.blocks(for: stage)
        #expect(parts[0].size == SIMD3(4, 0.5, 2))
        let backdrop = parts.first { $0.size.y == 2.6 }!
        #expect(local(backdrop, in: stage).z > 0.5, "the backdrop is at the side away from the open one")
        let steps = parts.filter { $0.size.z == 0.3 || $0.size.x == 0.3 }
        #expect(steps.count == 2 && steps.allSatisfy { local($0, in: stage).z < -1 })
    }

    @Test("A photobooth is a walled cabin and a display is a fenced platform")
    func otherAttractions() {
        let cabin = VenueGeometry.blocks(for: object(.entertainment, label: "PHOTO BOX"))
        #expect(cabin.filter { $0.size.y == 2.1 }.count == 3, "three walls")
        let display = VenueGeometry.blocks(for: object(.entertainment, label: "Display"))
        #expect(display.filter { $0.shape == .cylinder && $0.size.y == 0.9 }.count == 4, "four posts")
        #expect(display[0].size.y == 0.15)
    }

    @Test("Columns are cylinders as wide as their smaller side")
    func cylinders() {
        #expect(VenueGeometry.blocks(for: object(.block, catalogID: ObjectCatalog.columnID))[0].size.y == 3.5)
    }

    @Test("Walls, entertainment and flat areas have their own heights")
    func heights() {
        #expect(VenueGeometry.blocks(for: object(.wall))[0].size.y == 2.8)
        #expect(VenueGeometry.blocks(for: object(.entertainment))[0].size.y == 0.5)
        #expect(VenueGeometry.blocks(for: object(.block))[0].size.y == 0.8)
        #expect(VenueGeometry.blocks(for: object(.closedArea))[0].size.y == 0.15)
    }

    @Test("A turned plain object lands exactly where the 2D plan puts its corners")
    func rotationMatchesThePlan() {
        for degrees in [0.0, 30, 90, 137, 270] {
            let thing = object(.entertainment, rotation: degrees * .pi / 180)
            let block = VenueGeometry.blocks(for: thing)[0]
            let c = cos(block.rotationY), s = sin(block.rotationY)
            var fromBlock = Set<[Int]>()
            for (sx, sz) in [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)] as [(Float, Float)] {
                let corner = SIMD3(sx * block.size.x, 0, sz * block.size.z)
                let turned = SIMD3(corner.x * c + corner.z * s, 0, -corner.x * s + corner.z * c)
                fromBlock.insert([Int(((block.center.x + turned.x) * 1000).rounded()), Int(((block.center.z + turned.z) * 1000).rounded())])
            }
            let fromPlan = Set(LayoutGeometry.corners(of: thing.placement).map {
                [Int(($0.x * 1000).rounded()), Int(($0.y * 1000).rounded())]
            })
            #expect(fromBlock == fromPlan, "\(degrees)°")
        }
    }

    // MARK: Booths

    @Test("A booth is a stall: a mat, an awning, four posts, one part for each side, then valance and goods")
    func boothParts() {
        let booth = object(.booth, label: "B3", open: [.bottom])
        let parts = VenueGeometry.blocks(for: booth)
        #expect(parts.count > 1 + 1 + 4 + 4)
        let valance = parts.dropFirst(10).filter { $0.size.y == 0.28 }
        #expect(valance.count >= 2 && valance.allSatisfy { local($0, in: booth).z > 1 }, "the valance hangs at the open side")
        #expect(Set(valance.map(\.color)).count == 2, "in two colors")
        let roof = parts.max { top($0) < top($1) }!
        #expect(top(roof) > 2.3)
        let roofPlace = local(roof, in: booth)
        #expect(roofPlace.z + roof.size.z / 2 > 1.0 + 0.2, "the awning juts out over the open bottom side")
        #expect(roofPlace.z - roof.size.z / 2 > -1.0, "and stops short of the closed top side")
        #expect(abs(roofPlace.x) < 0.01 && roof.size.x < 4, "it does not reach the neighboring booths")
        #expect(parts.filter { $0.size.x == 0.12 && $0.size.z == 0.12 }.count == 4)
    }

    @Test("The awning is blue, or orange for a food booth")
    func awningColor() {
        func awning(_ label: String) -> SIMD4<Float> {
            VenueGeometry.blocks(for: object(.booth, label: label)).max { top($0) < top($1) }!.color
        }
        #expect(awning("B3") != awning("Food 1"))
    }

    @Test("Each open side has a low counter, and each closed side a tall panel")
    func openAndClosedSides() {
        let booth = object(.booth, label: "B3", open: [.bottom, .right])
        let parts = VenueGeometry.blocks(for: booth).dropFirst(6).prefix(4)   // after the mat, awning and posts
        let counters = parts.filter { $0.size.y < 1.2 }
        let panels = parts.filter { $0.size.y > 2 }
        #expect(counters.count == 2 && panels.count == 2)

        let sides = parts.map { local($0, in: booth) }
        // Bottom is the plan's down, which is +z. Right is +x. Top and left are the other way.
        #expect(counters.allSatisfy { local($0, in: booth).z > 0.5 || local($0, in: booth).x > 1 })
        #expect(sides.filter { $0.z > 0.5 }.count == 1 && sides.filter { $0.x > 1 }.count == 1)
        #expect(panels.allSatisfy { local($0, in: booth).z < -0.5 || local($0, in: booth).x < -1 })
        #expect(counters.allSatisfy { $0.color == SIMD4(0.99, 0.97, 0.92, 1) })
    }

    @Test("A turned booth keeps its counter on the same side as in the 2D plan")
    func turnedBooth() {
        for degrees in [0.0, 90, 180, 270, 40] {
            let booth = object(.booth, rotation: degrees * .pi / 180, open: [.bottom])
            let counter = VenueGeometry.blocks(for: booth).dropFirst(6).prefix(4).first { $0.size.y < 1.2 }!
            let strip = LayoutGeometry.stripPlacement(for: .bottom, of: booth.placement, depthM: 0.5).center
            let toCounter = SIMD2(counter.center.x - 10, counter.center.z - 6)
            let toStrip = SIMD2(Float(strip.x) - 10, Float(strip.y) - 6)
            #expect(simd_dot(simd_normalize(toCounter), simd_normalize(toStrip)) > 0.999, "\(degrees)°")
        }
    }

    @Test("The awnings of booths standing side by side stay apart")
    func awningsStayApart() {
        let left = object(.booth, center: SIMD2(10, 6), open: [.bottom])
        let right = object(.booth, center: SIMD2(14, 6), open: [.bottom])
        func roof(_ booth: LayoutObject) -> VenueBlock { VenueGeometry.blocks(for: booth).max { top($0) < top($1) }! }
        let gap = (roof(right).center.x - roof(right).size.x / 2) - (roof(left).center.x + roof(left).size.x / 2)
        #expect(gap > 0.05)
    }

    @Test("Nothing of a booth sticks out past its awning")
    func boothStaysInside() {
        for degrees in [0.0, 90, 33] {
            let booth = object(.booth, rotation: degrees * .pi / 180, open: [.left])
            for part in VenueGeometry.blocks(for: booth) {
                let place = local(part, in: booth)
                #expect(abs(place.x) <= 2.2 && abs(place.z) <= 1.2, "\(degrees)°")
            }
        }
    }

    @Test("A booth with no open side is closed all round")
    func closedBooth() {
        let parts = VenueGeometry.blocks(for: object(.booth)).dropFirst(6).prefix(4)
        #expect(parts.allSatisfy { $0.size.y > 2 })
    }

    // MARK: Doors

    private func door(_ direction: DoorDirection, size: SIMD2<Double> = SIMD2(1.8, 0.7)) -> LayoutObject {
        object(.door, label: "Door A", center: SIMD2(5, 3), size: size, flow: DoorFlow(direction: direction))
    }

    @Test("A door is a frame with a beam, leaves standing open, a colored strip on the floor, and a sign")
    func doorParts() {
        let parts = VenueGeometry.blocks(for: door(.entrance))
        #expect(parts.count == 7)
        let leaves = parts.filter { $0.size.z == 0.05 }
        #expect(leaves.count == 2 && leaves[0].rotationY == -leaves[1].rotationY, "a wide door has two leaves, mirrored")
        #expect(VenueGeometry.blocks(for: door(.entrance, size: SIMD2(0.9, 0.2))).filter { $0.size.z == 0.05 }.count == 1)
        #expect(parts.last!.center.y > 2.4 && parts.last!.color == leaves[0].color, "the sign sits over the beam")
        #expect(parts.filter { $0.size.y == 2.3 }.count == 2, "two posts")
        let beam = parts.first { $0.size.y == 0.15 }!
        #expect(beam.center.y > 2.3 && beam.size.x == 1.8)
        let strip = parts.first { $0.size.y == 0.04 }!
        #expect(strip.center.y < 0.05)
        let leaf = parts.first { $0.size.z == 0.05 }!
        #expect(leaf.rotationY != 0, "the leaf is swung open")
        #expect(leaf.color == strip.color)
    }

    @Test("A door's colors say which way people may go, and a disabled door has no leaf")
    func doorColors() {
        func stripColor(_ direction: DoorDirection) -> SIMD4<Float> {
            VenueGeometry.blocks(for: door(direction)).first { $0.size.y == 0.04 }!.color
        }
        #expect(Set([stripColor(.entrance), stripColor(.exit), stripColor(.both), stripColor(.disabled)]).count == 4)
        let closed = VenueGeometry.blocks(for: door(.disabled))
        #expect(closed.count == 4 && !closed.contains { $0.size.z == 0.05 })
    }

    @Test("A door in a side wall is built along the other axis")
    func sidewaysDoor() {
        let parts = VenueGeometry.blocks(for: door(.both, size: SIMD2(0.7, 1.8)))
        let posts = parts.filter { $0.size.y == 2.3 }
        #expect(posts.count == 2)
        #expect(posts.allSatisfy { abs($0.center.x - 5) < 0.01 })
        #expect(Set(posts.map { Int(($0.center.z - 3) * 100) }).count == 2)
        #expect(parts.first { $0.size.y == 0.15 }!.size.z == 1.8)
    }

    // MARK: Walls with openings

    private func wall(
        center: SIMD2<Double> = SIMD2(10, 5), size: SIMD2<Double> = SIMD2(20, 0.4), rotation: Double = 0
    ) -> LayoutObject {
        object(.wall, center: center, size: size, rotation: rotation)
    }

    private func doorAt(_ x: Double, y: Double = 5, size: SIMD2<Double> = SIMD2(1.8, 0.7),
                        direction: DoorDirection = .both) -> LayoutObject {
        object(.door, center: SIMD2(x, y), size: size, flow: DoorFlow(direction: direction))
    }

    private func walls(in layout: Layout) -> [VenueBlock] {
        VenueGeometry.blocks(for: layout).filter { $0.size.y == 2.8 }
    }

    private func layout(_ objects: [LayoutObject]) -> Layout {
        Layout(name: "T", sizeM: SIMD2(30, 20), hall: [SIMD2(0, 0), SIMD2(30, 0), SIMD2(30, 20), SIMD2(0, 20)], objects: objects)
    }

    @Test("A door opens a gap in the wall it stands in")
    func wallGap() {
        let pieces = walls(in: layout([wall(), doorAt(10)])).sorted { $0.center.x < $1.center.x }
        #expect(pieces.count == 2)
        #expect(abs(pieces[0].size.x - 9.1) < 0.01 && abs(pieces[1].size.x - 9.1) < 0.01)
        let gapStart = pieces[0].center.x + pieces[0].size.x / 2
        let gapEnd = pieces[1].center.x - pieces[1].size.x / 2
        #expect(abs(gapStart - 9.1) < 0.01 && abs(gapEnd - 10.9) < 0.01)
        #expect(pieces.allSatisfy { $0.size.z == 0.4 && $0.center.z == 5 })
    }

    @Test("Two doors make three pieces, and a door at the end makes one")
    func severalGaps() {
        #expect(walls(in: layout([wall(), doorAt(5), doorAt(15)])).count == 3)
        #expect(walls(in: layout([wall(), doorAt(0.9)])).count == 1)
    }

    @Test("A wall with no door in it stays whole")
    func wallWithoutDoor() {
        #expect(walls(in: layout([wall(), doorAt(10, y: 12)])).count == 1)
        #expect(walls(in: layout([wall()])).first?.size.x == 20)
    }

    @Test("A wall that runs the other way is cut the same way")
    func verticalWall() {
        let side = wall(center: SIMD2(5, 10), size: SIMD2(0.4, 20))
        let opening = doorAt(5, y: 10, size: SIMD2(0.7, 1.8))
        let pieces = walls(in: layout([side, opening])).sorted { $0.center.z < $1.center.z }
        #expect(pieces.count == 2)
        #expect(abs(pieces[0].size.z - 9.1) < 0.01)
    }

    @Test("A disabled door, a door across the wall, or a wall turned at an odd angle is not cut")
    func notCut() {
        #expect(walls(in: layout([wall(), doorAt(10, direction: .disabled)])).count == 1)
        #expect(walls(in: layout([wall(), doorAt(10, size: SIMD2(0.7, 1.8))])).count == 1)
        #expect(walls(in: layout([wall(rotation: 30 * .pi / 180), doorAt(10)])).count == 1)
    }

    @Test("A wall turned a quarter turn is still cut")
    func quarterTurnWall() {
        let turned = wall(center: SIMD2(10, 5), size: SIMD2(0.4, 20), rotation: .pi / 2)
        #expect(walls(in: layout([turned, doorAt(10)])).count == 2)
    }

    @Test("The floors cover the hall and the lobby")
    func floors() {
        let base = TestLayouts.hall()
        let floor = VenueGeometry.blocks(for: base)[0]
        #expect(floor.size.x == 24 && floor.size.z == 12)
        #expect(floor.center.y < 0)

        var withLobby = base
        withLobby.lobby = [SIMD2(10, 12.2), SIMD2(24, 12.2), SIMD2(24, 20), SIMD2(10, 20)]
        let blocks = VenueGeometry.blocks(for: withLobby)
        #expect(blocks[1].size.z == 7.8)
        let stalls = base.objects.filter { $0.kind == .booth }.count
        let doors = base.objects.filter { $0.kind == .door }.count
        #expect(blocks.count >= 2 + stalls * 10 + doors * 5)
    }

    @Test("Without a hall outline the floor is the layout's size")
    func floorFallback() {
        let layout = Layout(name: "Empty", sizeM: SIMD2(30, 20))
        let floor = VenueGeometry.blocks(for: layout)[0]
        #expect(floor.size.x == 30 && floor.size.z == 20)
    }
}

@Suite
struct OrbitCameraTests {
    private let plan = PlanFrame(origin: SIMD2(-1, -1), size: SIMD2(26, 14))

    @Test("It starts looking at the middle of the plan from the south, above it")
    func framing() {
        let camera = OrbitCamera.framing(plan: plan)
        #expect(camera.target == SIMD3(12, 0, 6))
        #expect(camera.position.y > 0)
        #expect(camera.position.z > camera.target.z)
        #expect(abs(camera.position.x - camera.target.x) < 1e-4)
    }

    @Test("The point it looks at is the middle of the screen")
    func projectsTargetToCenter() throws {
        let camera = OrbitCamera.framing(plan: plan)
        let spot = try #require(camera.project(camera.target, viewport: SIMD2(800, 600)))
        #expect(abs(spot.x - 400) < 0.5 && abs(spot.y - 300) < 0.5)
    }

    @Test("A point east of the middle is right of the screen's middle, and north of it is above")
    func directions() throws {
        let camera = OrbitCamera.framing(plan: plan)
        let middle = try #require(camera.project(camera.target, viewport: SIMD2(800, 600)))
        let east = try #require(camera.project(camera.target + SIMD3(5, 0, 0), viewport: SIMD2(800, 600)))
        let north = try #require(camera.project(camera.target + SIMD3(0, 0, -5), viewport: SIMD2(800, 600)))
        #expect(east.x > middle.x)
        #expect(north.y < middle.y)
    }

    @Test("A point behind the camera is not on screen")
    func behind() {
        let camera = OrbitCamera.framing(plan: plan)
        let behind = camera.position + (camera.position - camera.target)
        #expect(camera.project(behind, viewport: SIMD2(800, 600)) == nil)
    }

    @Test("Dragging turns around the target and tilts, and the tilt stops before the floor and the zenith")
    func orbit() {
        var camera = OrbitCamera.framing(plan: plan)
        let start = camera
        camera.orbit(dx: 50, dy: 0)
        #expect(camera.yaw != start.yaw && camera.pitch == start.pitch)
        #expect(abs(simd_length(camera.position - camera.target) - start.distance) < 1e-3)
        camera.orbit(dx: 0, dy: 100_000)
        #expect(camera.pitch == OrbitCamera.maximumPitch)
        camera.orbit(dx: 0, dy: -100_000)
        #expect(camera.pitch == OrbitCamera.minimumPitch)
    }

    @Test("Zooming moves in and out, within limits")
    func zoom() {
        var camera = OrbitCamera.framing(plan: plan)
        let start = camera.distance
        camera.zoom(20)
        #expect(camera.distance < start)
        camera.zoom(-60)
        #expect(camera.distance > start)
        camera.zoom(100_000)
        #expect(camera.distance == 15)
        camera.zoom(-100_000)
        #expect(camera.distance == 1200)
    }

    @Test("Moving slides the target across the floor and never up")
    func pan() {
        var camera = OrbitCamera.framing(plan: plan)
        let start = camera.target
        camera.pan(dx: 40, dy: 10)
        #expect(camera.target != start)
        #expect(camera.target.y == 0)
        camera.pan(dx: -40, dy: -10)
        #expect(simd_length(camera.target - start) < 1e-3)
    }

    @Test("Things in front of the camera land inside the screen's depth range")
    func clipSpace() {
        let camera = OrbitCamera.framing(plan: plan)
        let clip = camera.viewProjection(aspect: 4.0 / 3) * SIMD4(camera.target, 1)
        let ndc = SIMD3(clip.x, clip.y, clip.z) / clip.w
        #expect(abs(ndc.x) < 1e-4 && abs(ndc.y) < 1e-4)
        #expect(ndc.z > 0 && ndc.z < 1)
    }
}
