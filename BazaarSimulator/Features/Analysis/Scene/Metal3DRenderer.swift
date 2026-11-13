import AppKit
import Metal
import simd
import SwiftUI

/// Draws the 3D simulator with Metal: the venue, the visitors walking through it, the heat or path overlay,
/// and the markers at congested spots.
///
/// Everything of one kind is drawn in a single instanced call. A venue of hundreds of booths and tables is
/// two calls, and thousands of visitors are one, so the cost barely grows with the crowd. It draws into any
/// texture, so the window and the tests use the same code.
final class Metal3DRenderer {
    private struct Uniforms {
        var viewProjection: float4x4
        var lightDirection: SIMD4<Float>
        var cameraRight: SIMD4<Float>
        var cameraUp: SIMD4<Float>
        var overlayRect: SIMD4<Float>
        var overlayHeight: SIMD4<Float>
        var cameraPosition: SIMD4<Float>
        var inkColor: SIMD4<Float>
    }

    /// How a shape's edges are found, passed to the shader in the spare slot of an instance's scale.
    private enum Outline: Float {
        case box = 0
        case can = 1
        case figure = 2
        case none = 3
    }

    private struct Instance {
        var positionRotation: SIMD4<Float>
        var scale: SIMD4<Float>
        var color: SIMD4<Float>
    }

    /// The layout of a vertex, as the shader reads it.
    private struct MeshVertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }

    private struct GPUMesh {
        let vertices: MTLBuffer
        let indices: MTLBuffer
        let indexCount: Int
    }

    static let colorFormat = MTLPixelFormat.bgra8Unorm
    static let depthFormat = MTLPixelFormat.depth32Float
    /// Paper, with the venue drawn on it in ink.
    static let background = MTLClearColor(red: 0.957, green: 0.937, blue: 0.890, alpha: 1)
    static let inkColor = SIMD3<Float>(0.11, 0.15, 0.34)
    static let outlineWidthPixels: Float = 1.3

    static let visitorHeight: Float = 1.7
    static let visitorRadius: Float = 0.28
    static let spotRadius: Float = 2.0
    /// A label's width and height, in meters.
    static let labelSize = SIMD2<Float>(9, 1.7)
    static let labelHeight: Float = 6.6
    private static let visitorColors = Palette.visitorSeriesColors.map(rgba)
    private static let glowColor = rgba(.spotGlow)

    let device: MTLDevice
    let sampleCount: Int
    private let queue: MTLCommandQueue
    private let opaquePipeline: MTLRenderPipelineState
    private let blendedPipeline: MTLRenderPipelineState
    private let overlayPipeline: MTLRenderPipelineState
    private let labelPipeline: MTLRenderPipelineState
    private let writingDepth: MTLDepthStencilState
    private let readingDepth: MTLDepthStencilState
    private let cube: GPUMesh
    private let cylinder: GPUMesh
    private let capsule: GPUMesh

    private var venueID: UUID?
    private var venueBoxes: (buffer: MTLBuffer?, count: Int) = (nil, 0)
    private var venueCylinders: (buffer: MTLBuffer?, count: Int) = (nil, 0)
    /// Two textures that take turns, so the GPU never reads one while it is being rewritten.
    private var overlayTextures: [MTLTexture] = []
    private var nextOverlayTexture = 0
    private var labelTextures: [String: MTLTexture] = [:]
    private var multisampleColor: MTLTexture?
    private var depthTexture: MTLTexture?

    /// How many draw calls the last frame took. It does not depend on how many visitors there were.
    private(set) var drawCallCount = 0

    /// Nil when there is no GPU or the shaders do not compile.
    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice(), sampleCount: Int = 1) {
        guard let device,
              device.supportsTextureSampleCount(sampleCount),
              let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: Metal3DShaderSource.text, options: nil) else {
            return nil
        }
        self.device = device
        self.queue = queue
        self.sampleCount = sampleCount

        func pipeline(_ vertex: String, _ fragment: String, blended: Bool) -> MTLRenderPipelineState? {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            descriptor.rasterSampleCount = sampleCount
            descriptor.depthAttachmentPixelFormat = Self.depthFormat
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = Self.colorFormat
            if blended {
                // Colors are premultiplied by their alpha, so this is "source over".
                color.isBlendingEnabled = true
                color.rgbBlendOperation = .add
                color.alphaBlendOperation = .add
                color.sourceRGBBlendFactor = .one
                color.sourceAlphaBlendFactor = .one
                color.destinationRGBBlendFactor = .oneMinusSourceAlpha
                color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        func depthState(writes: Bool) -> MTLDepthStencilState? {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.depthCompareFunction = .less
            descriptor.isDepthWriteEnabled = writes
            return device.makeDepthStencilState(descriptor: descriptor)
        }
        func upload(_ mesh: MeshData) -> GPUMesh? {
            let vertices = mesh.vertices.map { MeshVertex(position: $0.position, normal: $0.normal) }
            guard let vertexBuffer = device.makeBuffer(
                bytes: vertices, length: MemoryLayout<MeshVertex>.stride * vertices.count, options: .storageModeShared
            ), let indexBuffer = device.makeBuffer(
                bytes: mesh.indices, length: MemoryLayout<UInt16>.stride * mesh.indices.count, options: .storageModeShared
            ) else { return nil }
            return GPUMesh(vertices: vertexBuffer, indices: indexBuffer, indexCount: mesh.indices.count)
        }

        guard let opaque = pipeline("solidVertex", "solidFragment", blended: false),
              let blended = pipeline("solidVertex", "solidFragment", blended: true),
              let overlay = pipeline("overlayVertex", "flatFragment", blended: true),
              let label = pipeline("labelVertex", "flatFragment", blended: true),
              let writing = depthState(writes: true),
              let reading = depthState(writes: false),
              let cube = upload(.cube),
              let cylinder = upload(.cylinder),
              let capsule = upload(.capsule(radius: Self.visitorRadius, height: Self.visitorHeight)) else {
            return nil
        }
        opaquePipeline = opaque
        blendedPipeline = blended
        overlayPipeline = overlay
        labelPipeline = label
        writingDepth = writing
        readingDepth = reading
        self.cube = cube
        self.cylinder = cylinder
        self.capsule = capsule
    }

    // MARK: Drawing

    /// Encodes one frame into `target`. Returns the command buffer so a caller can wait for it, or present a
    /// drawable with it.
    @discardableResult
    func render(
        _ frame: SimulationSceneFrame,
        venue: SimulationVenue,
        camera: OrbitCamera,
        to target: MTLTexture,
        present drawable: MTLDrawable? = nil
    ) -> MTLCommandBuffer? {
        loadVenue(venue)
        drawCallCount = 0
        guard let commands = queue.makeCommandBuffer() else { return nil }

        let pass = MTLRenderPassDescriptor()
        if sampleCount > 1 {
            pass.colorAttachments[0].texture = attachment(&multisampleColor, like: target, format: Self.colorFormat)
            pass.colorAttachments[0].resolveTexture = target
            pass.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].storeAction = .store
        }
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = Self.background
        pass.depthAttachment.texture = attachment(&depthTexture, like: target, format: Self.depthFormat)
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)

        let axes = camera.screenAxes
        let plan = venue.plan
        var uniforms = Uniforms(
            viewProjection: camera.viewProjection(aspect: Float(target.width) / Float(target.height)),
            lightDirection: SIMD4(simd_normalize(SIMD3<Float>(-20, -40, -20)), 0.55),
            cameraRight: SIMD4(axes.right, 0),
            cameraUp: SIMD4(axes.up, 0),
            overlayRect: SIMD4(
                Float(plan.origin.x), Float(plan.origin.y),
                Float(plan.origin.x + plan.size.x), Float(plan.origin.y + plan.size.y)
            ),
            overlayHeight: SIMD4(0.04, 0, 0, 0),
            cameraPosition: SIMD4(camera.position, 1),
            inkColor: SIMD4(Self.inkColor, Self.outlineWidthPixels)
        )

        // Solid things first, with the depth buffer sorting out what hides what.
        encoder.setDepthStencilState(writingDepth)
        encoder.setRenderPipelineState(opaquePipeline)
        draw(venueBoxes.buffer, count: venueBoxes.count, mesh: cube, uniforms: &uniforms, encoder: encoder)
        draw(venueCylinders.buffer, count: venueCylinders.count, mesh: cylinder, uniforms: &uniforms, encoder: encoder)
        let visitors = visitorInstances(frame.visitors)
        draw(buffer(visitors), count: visitors.count, mesh: capsule, uniforms: &uniforms, encoder: encoder)

        // Then see-through things: hidden by solid ones, but not hiding each other. The flat pictures are
        // seen from either side, so they are drawn whichever way they face.
        encoder.setDepthStencilState(readingDepth)
        encoder.setCullMode(.none)
        if let overlay = frame.overlay, let texture = overlayTexture(for: overlay) {
            encoder.setRenderPipelineState(overlayPipeline)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            drawCallCount += 1
        }
        // The glowing discs and beams are solid shapes, so only their outer faces are blended.
        encoder.setCullMode(.back)
        let markers = markerInstances(frame.spots)
        encoder.setRenderPipelineState(blendedPipeline)
        draw(buffer(markers), count: markers.count, mesh: cylinder, uniforms: &uniforms, encoder: encoder)

        encoder.setCullMode(.none)
        encoder.setRenderPipelineState(labelPipeline)
        for spot in frame.spots {
            guard let texture = labelTexture("\(spot.number) · Grade \(spot.grade.letter)") else { continue }
            var center = SIMD4<Float>(Float(spot.x), Self.labelHeight, Float(spot.z), 0)
            encoder.setVertexBytes(&center, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            drawCallCount += 1
        }

        encoder.endEncoding()
        if let drawable { commands.present(drawable) }
        commands.commit()
        return commands
    }

    private func draw(
        _ instances: MTLBuffer?,
        count: Int,
        mesh: GPUMesh,
        uniforms: inout Uniforms,
        encoder: MTLRenderCommandEncoder
    ) {
        guard let instances, count > 0 else { return }
        encoder.setVertexBuffer(mesh.vertices, offset: 0, index: 0)
        encoder.setVertexBuffer(instances, offset: 0, index: 1)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 2)
        encoder.drawIndexedPrimitives(
            type: .triangle, indexCount: mesh.indexCount, indexType: .uint16,
            indexBuffer: mesh.indices, indexBufferOffset: 0, instanceCount: count
        )
        drawCallCount += 1
    }

    // MARK: Instances

    private func loadVenue(_ venue: SimulationVenue) {
        guard venueID != venue.id else { return }
        venueID = venue.id
        func instances(_ shape: VenueBlock.Shape) -> [Instance] {
            venue.blocks.filter { $0.shape == shape }.map {
                Instance(
                    positionRotation: SIMD4($0.center, $0.rotationY),
                    scale: SIMD4($0.size, (shape == .box ? Outline.box : .can).rawValue),
                    color: $0.color
                )
            }
        }
        let boxes = instances(.box), cylinders = instances(.cylinder)
        venueBoxes = (buffer(boxes), boxes.count)
        venueCylinders = (buffer(cylinders), cylinders.count)
    }

    private func visitorInstances(_ visitors: [SimulationSceneFrame.Visitor]) -> [Instance] {
        visitors.map { visitor in
            let spread = min(1 + 0.15 * Float(max(visitor.people - 1, 0)), 2.5)
            return Instance(
                positionRotation: SIMD4(Float(visitor.x), Self.visitorHeight / 2, Float(visitor.z), 0),
                scale: SIMD4(spread, 1, spread, Outline.figure.rawValue),
                color: Self.visitorColors[visitor.typeIndex % Self.visitorColors.count]
            )
        }
    }

    /// A glowing disc on the floor and a beam above it for each watched spot. A more crowded spot is wider
    /// and stronger.
    private func markerInstances(_ spots: [SimulationSceneFrame.Spot]) -> [Instance] {
        var instances: [Instance] = []
        for spot in spots {
            let level = Float(min(max(spot.level, 0), 1))
            let width = 2 * Self.spotRadius * (0.8 + 0.4 * level)
            var disc = Self.glowColor
            disc.w = 0.35 + 0.4 * level
            var beam = Self.glowColor
            beam.w = 0.4
            instances.append(Instance(
                positionRotation: SIMD4(Float(spot.x), 0.08, Float(spot.z), 0), scale: SIMD4(width, 0.06, width, Outline.none.rawValue), color: disc
            ))
            instances.append(Instance(
                positionRotation: SIMD4(Float(spot.x), 3, Float(spot.z), 0), scale: SIMD4(0.6, 6, 0.6, Outline.none.rawValue), color: beam
            ))
        }
        return instances
    }

    private func buffer(_ instances: [Instance]) -> MTLBuffer? {
        guard !instances.isEmpty else { return nil }
        return device.makeBuffer(
            bytes: instances, length: MemoryLayout<Instance>.stride * instances.count, options: .storageModeShared
        )
    }

    // MARK: Textures

    private func attachment(_ cache: inout MTLTexture?, like target: MTLTexture, format: MTLPixelFormat) -> MTLTexture? {
        if let cache, cache.width == target.width, cache.height == target.height { return cache }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format, width: target.width, height: target.height, mipmapped: false
        )
        descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
        descriptor.sampleCount = sampleCount
        descriptor.usage = .renderTarget
        descriptor.storageMode = .private
        cache = device.makeTexture(descriptor: descriptor)
        return cache
    }

    private func overlayTexture(for pixels: FieldImage.Pixels) -> MTLTexture? {
        guard pixels.width > 0, pixels.height > 0, pixels.bytes.count == pixels.width * pixels.height * 4 else { return nil }
        if overlayTextures.count < 2 || overlayTextures.contains(where: { $0.width != pixels.width || $0.height != pixels.height }) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: pixels.width, height: pixels.height, mipmapped: false
            )
            descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
            guard let first = device.makeTexture(descriptor: descriptor),
                  let second = device.makeTexture(descriptor: descriptor) else { return nil }
            overlayTextures = [first, second]
        }
        let texture = overlayTextures[nextOverlayTexture]
        nextOverlayTexture = (nextOverlayTexture + 1) % 2
        texture.replace(
            region: MTLRegionMake2D(0, 0, pixels.width, pixels.height), mipmapLevel: 0,
            withBytes: pixels.bytes, bytesPerRow: pixels.width * 4
        )
        return texture
    }

    /// Text as a picture, made once per distinct text.
    private func labelTexture(_ text: String) -> MTLTexture? {
        if let existing = labelTextures[text] { return existing }
        let width = 256, height = Int((Float(width) * Self.labelSize.y / Self.labelSize.x).rounded())
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            NSColor(white: 0, alpha: 0.6).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: 0, y: 0, width: width, height: height),
                xRadius: CGFloat(height) / 2, yRadius: CGFloat(height) / 2
            ).fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: CGFloat(height) * 0.55, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let string = NSAttributedString(string: text, attributes: attributes)
            let size = string.size()
            string.draw(at: NSPoint(x: (CGFloat(width) - size.width) / 2, y: (CGFloat(height) - size.height) / 2))
            return true
        }
        guard drawn else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        labelTextures[text] = texture
        return texture
    }

    private static func rgba(_ color: Color) -> SIMD4<Float> {
        let converted = NSColor(color).usingColorSpace(.sRGB) ?? .white
        return SIMD4(
            Float(converted.redComponent), Float(converted.greenComponent),
            Float(converted.blueComponent), Float(converted.alphaComponent)
        )
    }
}
