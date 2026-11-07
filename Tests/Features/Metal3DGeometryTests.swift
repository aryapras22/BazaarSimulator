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
    private func layoutObject(_ kind: LayoutObjectKind, label: String = "X1", rotation: Double = 0,
                              flow: DoorFlow? = nil) -> LayoutObject {
        LayoutObject(
            kind: kind, label: label,
            placement: Placement(center: SIMD2(10, 6), sizeM: SIMD2(4, 2), rotationRadians: rotation),
            doorFlow: flow
        )
    }

    @Test("Booths are 2.2 m tall boxes standing on the floor, in a food or other color")
    func booths() {
        let booth = VenueGeometry.block(for: layoutObject(.booth, label: "B3"))
        #expect(booth.shape == .box)
        #expect(booth.size == SIMD3(4, 2.2, 2))
        #expect(booth.center == SIMD3(10, 1.1, 6))
        let food = VenueGeometry.block(for: layoutObject(.booth, label: "Food 1"))
        #expect(food.color != booth.color)
    }

    @Test("Tables and pillars are cylinders as wide as their smaller side")
    func cylinders() {
        let table = VenueGeometry.block(for: layoutObject(.table))
        #expect(table.shape == .cylinder)
        #expect(table.size == SIMD3(2, 0.75, 2))
        #expect(VenueGeometry.block(for: layoutObject(.pillar)).size.y == 3.5)
    }

    @Test("Walls, stages and flat areas have their own heights")
    func heights() {
        #expect(VenueGeometry.block(for: layoutObject(.wall)).size.y == 2.8)
        #expect(VenueGeometry.block(for: layoutObject(.stage)).size.y == 0.5)
        for kind in [LayoutObjectKind.closedArea, .block, .fixture, .rail, .audienceArea] {
            #expect(VenueGeometry.block(for: layoutObject(kind)).size.y == 0.15, "\(kind)")
        }
    }

    @Test("A door lies on the floor, colored by which way it lets people go")
    func doors() {
        let entrance = VenueGeometry.block(for: layoutObject(.door, flow: DoorFlow(direction: .entrance)))
        let exit = VenueGeometry.block(for: layoutObject(.door, flow: DoorFlow(direction: .exit)))
        let both = VenueGeometry.block(for: layoutObject(.door, flow: DoorFlow(direction: .both)))
        #expect(entrance.size.y == 0.04)
        #expect(Set([entrance.color, exit.color, both.color]).count == 3)
    }

    @Test("A turned object lands exactly where the 2D plan puts its corners")
    func rotationMatchesThePlan() {
        for degrees in [0.0, 30, 90, 137, 270] {
            let object = layoutObject(.booth, rotation: degrees * .pi / 180)
            let block = VenueGeometry.block(for: object)
            let c = cos(block.rotationY), s = sin(block.rotationY)
            var fromBlock = Set<[Int]>()
            for (sx, sz) in [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)] as [(Float, Float)] {
                let local = SIMD3(sx * block.size.x, 0, sz * block.size.z)
                let turned = SIMD3(local.x * c + local.z * s, 0, -local.x * s + local.z * c)
                fromBlock.insert([Int(((block.center.x + turned.x) * 1000).rounded()), Int(((block.center.z + turned.z) * 1000).rounded())])
            }
            let fromPlan = Set(LayoutGeometry.corners(of: object.placement).map {
                [Int(($0.x * 1000).rounded()), Int(($0.y * 1000).rounded())]
            })
            #expect(fromBlock == fromPlan, "\(degrees)°")
        }
    }

    @Test("The floors cover the hall and the lobby")
    func floors() {
        let layout = TestLayouts.hall()
        let floor = VenueGeometry.blocks(for: layout)[0]
        #expect(floor.size.x == 24 && floor.size.z == 12)
        #expect(floor.center.y < 0)

        var withLobby = layout
        withLobby.lobby = [SIMD2(10, 12.2), SIMD2(24, 12.2), SIMD2(24, 20), SIMD2(10, 20)]
        let blocks = VenueGeometry.blocks(for: withLobby)
        #expect(blocks.count == layout.objects.count + 2)
        #expect(blocks[1].size.z == 7.8)
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
        #expect(camera.distance == 6)
        camera.zoom(-100_000)
        #expect(camera.distance == 800)
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
