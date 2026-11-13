import Metal
import simd
import SwiftUI
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct Metal3DRendererTests {
    private struct Picture {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func pixel(_ x: Int, _ y: Int) -> SIMD3<Double> {
            let index = (min(max(y, 0), height - 1) * width + min(max(x, 0), width - 1)) * 4
            return SIMD3(Double(bytes[index + 2]), Double(bytes[index + 1]), Double(bytes[index])) / 255
        }

        func pixel(_ point: SIMD2<Float>) -> SIMD3<Double> { pixel(Int(point.x), Int(point.y)) }
    }

    private let size = SIMD2<Int>(240, 180)
    // Computed, not stored: a suite instance with a 32-byte aligned stored property crashes the test runner.
    private var background: SIMD3<Double> { SIMD3(0.957, 0.937, 0.890) }

    private func plan(_ w: Double = 40, _ d: Double = 40) -> PlanFrame {
        PlanFrame(origin: SIMD2(-w / 2, -d / 2), size: SIMD2(w, d))
    }

    private func venue(_ blocks: [VenueBlock] = [], plan: PlanFrame? = nil) -> SimulationVenue {
        SimulationVenue(id: UUID(), blocks: blocks, plan: plan ?? self.plan())
    }

    private func box(at center: SIMD3<Float>, size: SIMD3<Float>, color: SIMD4<Float>) -> VenueBlock {
        VenueBlock(shape: .box, center: center, size: size, rotationY: 0, color: color)
    }

    /// The cameras here were placed for a 60 degree view. This moves them back so they frame the same scene.
    private var reach: Float { tan(.pi / 6) / tan(OrbitCamera.fieldOfView / 2) }

    private func topDown(distance: Float = 40) -> OrbitCamera {
        OrbitCamera(target: .zero, yaw: 0, pitch: OrbitCamera.maximumPitch, distance: distance * reach)
    }

    private func draw(
        _ frame: SimulationSceneFrame = SimulationSceneFrame(),
        venue: SimulationVenue? = nil,
        camera: OrbitCamera? = nil,
        samples: Int = 1,
        using shared: Metal3DRenderer? = nil
    ) throws -> Picture {
        let renderer = try shared ?? #require(Metal3DRenderer(sampleCount: samples))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: Metal3DRenderer.colorFormat, width: size.x, height: size.y, mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = renderer.device.hasUnifiedMemory ? .shared : .managed
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let commands = try #require(renderer.render(frame, venue: venue ?? self.venue(), camera: camera ?? topDown(), to: texture))
        commands.waitUntilCompleted()
        if !renderer.device.hasUnifiedMemory {
            let sync = try #require(renderer.device.makeCommandQueue()?.makeCommandBuffer())
            sync.makeBlitCommandEncoder()?.synchronize(resource: texture)
            sync.commit()
            sync.waitUntilCompleted()
        }
        var bytes = [UInt8](repeating: 0, count: size.x * size.y * 4)
        texture.getBytes(&bytes, bytesPerRow: size.x * 4, from: MTLRegionMake2D(0, 0, size.x, size.y), mipmapLevel: 0)
        return Picture(width: size.x, height: size.y, bytes: bytes)
    }

    private func visitor(_ id: Int, x: Double, z: Double, type: Int = 0, people: Int = 1) -> SimulationSceneFrame.Visitor {
        .init(id: id, x: x, z: z, typeIndex: type, people: people)
    }

    private func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ tolerance: Double = 0.05) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
    }

    @Test("The shaders compile and a renderer starts, with and without antialiasing")
    func starts() throws {
        _ = try #require(Metal3DRenderer(sampleCount: 1))
        _ = try #require(Metal3DRenderer(sampleCount: 4))
    }

    @Test("An empty venue is just the background")
    func empty() throws {
        let picture = try draw()
        #expect(near(picture.pixel(10, 10), background, 0.01))
        #expect(near(picture.pixel(120, 90), background, 0.01))
    }

    @Test("A block is drawn in its color, lit from above, and not past its edges")
    func block() throws {
        let red = box(at: SIMD3(0, 0.5, 0), size: SIMD3(10, 1, 10), color: SIMD4(1, 0, 0, 1))
        let picture = try draw(venue: venue([red]))
        let middle = picture.pixel(120, 90)
        #expect(middle.x > 0.5 && middle.y < 0.1 && middle.z < 0.1)
        #expect(near(picture.pixel(5, 5), background, 0.01))
    }

    @Test("A visitor is drawn in the color of its type")
    func visitorColor() throws {
        var frame = SimulationSceneFrame()
        frame.visitors = [visitor(1, x: 0, z: 0, type: 0), visitor(2, x: 8, z: 0, type: 3)]
        let camera = topDown()
        let picture = try draw(frame, camera: camera)
        let viewport = SIMD2(Float(size.x), Float(size.y))
        let blue = picture.pixel(try #require(camera.project(SIMD3(0, 1.7, 0), viewport: viewport)))
        let white = picture.pixel(try #require(camera.project(SIMD3(8, 1.7, 0), viewport: viewport)))
        #expect(blue.z > blue.x && blue.z > 0.3)
        #expect(white.x > 0.6 && white.y > 0.6 && white.z > 0.6)
    }

    @Test("A bigger group is a wider figure")
    func groups() throws {
        func lit(_ people: Int) throws -> Int {
            var frame = SimulationSceneFrame()
            frame.visitors = [visitor(1, x: 0, z: 0, type: 3, people: people)]
            let picture = try draw(frame)
            return (0..<(size.x * size.y)).filter { !near(picture.pixel($0 % size.x, $0 / size.x), background, 0.02) }.count
        }
        #expect(try lit(8) > lit(1))
    }

    @Test("Visitors are placed where the simulation put them")
    func visitorPlacement() throws {
        var frame = SimulationSceneFrame()
        frame.visitors = [visitor(1, x: -7, z: 4, type: 3)]
        let camera = topDown()
        let picture = try draw(frame, camera: camera)
        let viewport = SIMD2(Float(size.x), Float(size.y))
        let there = try #require(camera.project(SIMD3(-7, 1.7, 4), viewport: viewport))
        #expect(picture.pixel(there).x > 0.6)
        #expect(near(picture.pixel(there + SIMD2(0, 40)), background, 0.02))
    }

    @Test("A wall hides a visitor behind it, and does not hide one in front of it")
    func depth() throws {
        let wall = box(at: SIMD3(0, 2, 0), size: SIMD3(40, 4, 1), color: SIMD4(0, 1, 0, 1))
        let camera = OrbitCamera(target: SIMD3(0, 1, 0), yaw: 0, pitch: 0.2, distance: 30 * reach)
        let viewport = SIMD2(Float(size.x), Float(size.y))
        var frame = SimulationSceneFrame()
        frame.visitors = [visitor(1, x: 0, z: -4, type: 3), visitor(2, x: 6, z: 9, type: 3)]
        let picture = try draw(frame, venue: venue([wall]), camera: camera)

        let behind = picture.pixel(try #require(camera.project(SIMD3(0, 0.9, -4), viewport: viewport)))
        let front = picture.pixel(try #require(camera.project(SIMD3(6, 0.9, 9), viewport: viewport)))
        #expect(behind.y > behind.x && behind.y > behind.z, "the wall is green")
        #expect(front.x > 0.5 && front.z > 0.5, "the visitor is white")
    }

    @Test("The overlay's left is the plan's west and its top is the plan's north")
    func overlayOrientation() throws {
        // Left half red, right half green; top half blue, bottom half yellow.
        func image(_ color: (Int, Int) -> SIMD3<UInt8>) -> FieldImage.Pixels {
            var bytes: [UInt8] = []
            for row in 0..<4 { for column in 0..<4 {
                let c = color(column, row)
                bytes += [c.x, c.y, c.z, 255]
            } }
            return FieldImage.Pixels(width: 4, height: 4, bytes: bytes)
        }
        let camera = topDown()
        let viewport = SIMD2(Float(size.x), Float(size.y))
        let floor = box(at: SIMD3(0, -0.05, 0), size: SIMD3(40, 0.1, 40), color: SIMD4(0.1, 0.1, 0.1, 1))

        var sides = SimulationSceneFrame()
        sides.overlay = image { column, _ in column < 2 ? SIMD3(255, 0, 0) : SIMD3(0, 255, 0) }
        let leftRight = try draw(sides, venue: venue([floor]), camera: camera)
        let west = leftRight.pixel(try #require(camera.project(SIMD3(-10, 0, 0), viewport: viewport)))
        let east = leftRight.pixel(try #require(camera.project(SIMD3(10, 0, 0), viewport: viewport)))
        #expect(west.x > 0.6 && west.y < 0.3, "west is red")
        #expect(east.y > 0.6 && east.x < 0.3, "east is green")

        var rows = SimulationSceneFrame()
        rows.overlay = image { _, row in row < 2 ? SIMD3(0, 0, 255) : SIMD3(255, 255, 0) }
        let topBottom = try draw(rows, venue: venue([floor]), camera: camera)
        let north = topBottom.pixel(try #require(camera.project(SIMD3(0, 0, -10), viewport: viewport)))
        let south = topBottom.pixel(try #require(camera.project(SIMD3(0, 0, 10), viewport: viewport)))
        #expect(north.z > 0.6 && north.x < 0.3, "north is blue")
        #expect(south.x > 0.6 && south.y > 0.6 && south.z < 0.3, "south is yellow")
    }

    @Test("The overlay does not hide a tall block standing on it")
    func overlayBelowBlocks() throws {
        let booth = box(at: SIMD3(0, 1.1, 0), size: SIMD3(6, 2.2, 6), color: SIMD4(0, 0, 1, 1))
        var frame = SimulationSceneFrame()
        frame.overlay = FieldImage.Pixels(width: 1, height: 1, bytes: [255, 0, 0, 255])
        let picture = try draw(frame, venue: venue([booth]), camera: topDown())
        let top = picture.pixel(120, 90)
        #expect(top.z > top.x, "the booth is on top of the red overlay")
    }

    @Test("A congested spot glows red and wears a label")
    func marker() throws {
        var frame = SimulationSceneFrame()
        frame.spots = [.init(number: 2, x: 0, z: 0, level: 1, grade: .e)]
        let camera = OrbitCamera(target: SIMD3(0, 4, 0), yaw: 0, pitch: 0.9, distance: 13 * reach)
        let viewport = SIMD2(Float(size.x), Float(size.y))
        let picture = try draw(frame, camera: camera)
        let glow = picture.pixel(try #require(camera.project(SIMD3(1.5, 0.08, 0), viewport: viewport)))
        #expect(glow.x > glow.z + 0.1 && glow.z < background.z - 0.1)

        let label = try #require(camera.project(SIMD3(0, Metal3DRenderer.labelHeight, 0), viewport: viewport))
        var dark = 0
        for dy in -14...14 { for dx in -60...60 where picture.pixel(Int(label.x) + dx, Int(label.y) + dy).x < 0.5 { dark += 1 } }
        #expect(dark > 20, "the label's dark plate")
    }

    @Test("Antialiasing softens edges that plain drawing leaves jagged")
    func antialiasing() throws {
        var turned = box(at: SIMD3(0, 0.5, 0), size: SIMD3(12, 1, 12), color: SIMD4(1, 1, 1, 1))
        turned.rotationY = .pi / 7
        let scene = venue([turned])
        func middleTones(_ picture: Picture) -> Int {
            Set((0..<size.x).map { Int(picture.pixel($0, 86).x * 100) }).count
        }
        let sharp = try draw(venue: scene, samples: 1)
        let smooth = try draw(venue: scene, samples: 4)
        #expect(middleTones(smooth) > middleTones(sharp))
    }

    @Test("Draw calls stay the same however many visitors there are")
    func drawCallsDoNotGrow() throws {
        let renderer = try #require(Metal3DRenderer(sampleCount: 1))
        let blocks = (0..<300).map { box(at: SIMD3(Float($0 % 20) * 2 - 20, 1, Float($0 / 20) * 2 - 15), size: SIMD3(1.5, 2, 1.5), color: SIMD4(0.3, 0.5, 0.9, 1)) }
        let scene = venue(blocks)
        func calls(_ visitors: Int) throws -> Int {
            var frame = SimulationSceneFrame()
            frame.visitors = (0..<visitors).map { visitor($0, x: Double($0 % 50) - 25, z: Double($0 / 50 % 40) - 20, type: $0 % 4) }
            _ = try draw(frame, venue: scene, using: renderer)
            return renderer.drawCallCount
        }
        let few = try calls(10)
        let many = try calls(10_000)
        #expect(few == many)
        #expect(many <= 4)
    }

    @Test("Ten thousand visitors draw quickly")
    func manyVisitors() throws {
        let renderer = try #require(Metal3DRenderer(sampleCount: 4))
        var frame = SimulationSceneFrame()
        frame.visitors = (0..<10_000).map { visitor($0, x: Double($0 % 100) * 0.4 - 20, z: Double($0 / 100) * 0.4 - 20, type: $0 % 4) }
        let start = Date()
        for _ in 0..<5 { _ = try draw(frame, using: renderer) }
        #expect(Date().timeIntervalSince(start) / 5 < 0.25)
    }

    @Test("A new venue replaces the old one")
    func venueChanges() throws {
        let renderer = try #require(Metal3DRenderer(sampleCount: 1))
        let red = venue([box(at: SIMD3(0, 0.5, 0), size: SIMD3(10, 1, 10), color: SIMD4(1, 0, 0, 1))])
        let green = venue([box(at: SIMD3(0, 0.5, 0), size: SIMD3(10, 1, 10), color: SIMD4(0, 1, 0, 1))])
        let first = try draw(venue: red, using: renderer).pixel(120, 90)
        let second = try draw(venue: green, using: renderer).pixel(120, 90)
        let again = try draw(venue: green, using: renderer).pixel(120, 90)
        #expect(first.x > first.y && second.y > second.x && near(second, again, 0.001))
    }

    @Test("A booth seen from the front has a cream counter under a colored awning")
    func boothLooksLikeABooth() throws {
        let booth = LayoutObject(
            kind: .booth, label: "B3",
            placement: Placement(center: SIMD2(0, 0), sizeM: SIMD2(4, 3)),
            openSides: [.bottom]
        )
        let scene = venue(VenueGeometry.blocks(for: booth))
        let camera = OrbitCamera(target: SIMD3(0, 1, 0), yaw: 0, pitch: 0.35, distance: 11 * reach)
        let picture = try draw(venue: scene, camera: camera)
        let viewport = SIMD2(Float(size.x), Float(size.y))

        let counter = picture.pixel(try #require(camera.project(SIMD3(0, 0.6, 1.3), viewport: viewport)))
        #expect(counter.x > 0.55 && counter.y > 0.5 && counter.z > 0.35, "the counter is cream")
        let awning = picture.pixel(try #require(camera.project(SIMD3(0, 2.35, 1.6), viewport: viewport)))
        #expect(awning.z > awning.x, "the awning is blue")
        let post = picture.pixel(try #require(camera.project(SIMD3(-1.94, 1.8, 1.44), viewport: viewport)))
        #expect(post.x < 0.3 && post.y < 0.3 && post.z < 0.35, "a dark post stands at the corner")
    }

    @Test("A doorway is open: wall on both sides, a gap between, and a colored leaf standing in it")
    func doorwayIsOpen() throws {
        let wall = LayoutObject(
            kind: .wall, label: "Wall", placement: Placement(center: SIMD2(0, 0), sizeM: SIMD2(12, 0.4))
        )
        let door = LayoutObject(
            kind: .door, label: "Door A", placement: Placement(center: SIMD2(0, 0), sizeM: SIMD2(1.4, 0.6)),
            doorFlow: DoorFlow(direction: .entrance)
        )
        let layout = Layout(name: "T", sizeM: SIMD2(12, 8), hall: [], objects: [wall, door])
        let scene = venue(Array(VenueGeometry.blocks(for: layout).dropFirst()))
        let camera = OrbitCamera(target: SIMD3(0, 1.4, 0), yaw: 0, pitch: 0.2, distance: 16 * reach)
        let picture = try draw(venue: scene, camera: camera)
        let viewport = SIMD2(Float(size.x), Float(size.y))

        func at(_ x: Float, _ y: Float, _ z: Float) throws -> SIMD3<Double> {
            picture.pixel(try #require(camera.project(SIMD3(x, y, z), viewport: viewport)))
        }
        #expect(!near(try at(-4, 1.5, 0.2), background, 0.03), "wall on the left")
        #expect(!near(try at(4, 1.5, 0.2), background, 0.03), "wall on the right")
        #expect(near(try at(0.35, 1.4, 0), background, 0.04), "the doorway is open")
        let leaf = try at(-0.38, 1.0, 0.545)
        #expect(leaf.y > leaf.x && leaf.y > leaf.z, "the open leaf is green, for an entrance")
    }

    @Test("A real layout draws, with its booths standing above the floor")
    func realLayout() throws {
        let layout = TestLayouts.hall()
        let blocks = VenueGeometry.blocks(for: layout)
        let plan = PlanFrame(origin: SIMD2(-1, -1), size: SIMD2(26, 14))
        let scene = SimulationVenue(id: UUID(), blocks: blocks, plan: plan)
        let picture = try draw(venue: scene, camera: OrbitCamera.framing(plan: plan))
        let tones = Set((0..<size.x).flatMap { x in (0..<size.y).map { Int(picture.pixel(x, $0).z * 20) } })
        #expect(tones.count > 4, "more than a flat color")
    }
}
