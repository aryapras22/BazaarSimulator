import AppKit
import CoreGraphics
import SpriteKit
import SwiftUI
import simd

/// Tracks the 2D SpriteKit camera state so SwiftUI overlays (such as Congestion spot markers)
/// stay locked to their exact floor coordinates while panning and zooming.
struct SpriteCameraTransform: Equatable {
    static let pointsPerMetre: CGFloat = 20.0

    var cameraPosition: CGPoint = .zero
    var cameraScale: CGFloat = 1.0
    var viewSize: CGSize = .zero

    /// Converts a point in layout metres `(x, y)` into SwiftUI view coordinates (top-left origin).
    func swiftUIPoint(for pointM: SIMD2<Double>, in layout: Layout, fallbackSize: CGSize) -> CGPoint {
        let effectiveView = (viewSize.width > 10 && viewSize.height > 10) ? viewSize : fallbackSize
        let scale = max(0.05, cameraScale)
        let sceneX = CGFloat(pointM.x) * Self.pointsPerMetre
        let sceneY = CGFloat(layout.sizeM.y - pointM.y) * Self.pointsPerMetre
        return CGPoint(
            x: effectiveView.width / 2 + (sceneX - cameraPosition.x) / scale,
            y: effectiveView.height / 2 - (sceneY - cameraPosition.y) / scale
        )
    }
}

/// Continuous smoothed footfall field rendered as smooth path ribbons in 2D Walking Routes mode.
struct WalkingRoutesGrid: Equatable {
    let origin: SIMD2<Double>
    let tileM: Double
    let columns: Int
    let rows: Int
    let values: [Double]
}

/// A lightweight 2D SpriteKit view that renders the venue floor plan, smooth radial heatmap, and moving visitors.
/// Supports dragging to pan/scroll and scrolling or pinching to zoom.
struct Simulation2DSpriteView: NSViewRepresentable {
    enum OverlayStyle: Equatable {
        case heatmap
        case walkingRoutes
    }

    let layout: Layout
    var legend: Legend = Legend()
    var visitors: [SimulatedVisitor] = []
    var densityCells: [DensityCell] = []
    var walkingRoutesGrid: WalkingRoutesGrid?
    var showHeatmap = false
    var overlayStyle: OverlayStyle = .heatmap
    var backgroundColor: Color = Palette.simulationBackground
    var zoomRequest: CameraZoomRequest?
    var onCameraChange: ((SpriteCameraTransform) -> Void)?

    func makeNSView(context: Context) -> InteractiveSKView {
        let skView = InteractiveSKView()
        skView.ignoresSiblingOrder = false
        skView.preferredFramesPerSecond = 60
        skView.allowsTransparency = true
        skView.wantsLayer = true
        skView.layer?.backgroundColor = NSColor(backgroundColor).usingColorSpace(.sRGB)?.cgColor
        let scene = Venue2DScene(size: CGSize(width: 1000, height: 700))
        scene.scaleMode = .resizeFill
        scene.onCameraChange = onCameraChange
        skView.presentScene(scene)
        skView.venueScene = scene
        context.coordinator.scene = scene
        context.coordinator.lastZoomRequestID = zoomRequest?.id
        return skView
    }

    func updateNSView(_ skView: InteractiveSKView, context: Context) {
        skView.layer?.backgroundColor = NSColor(backgroundColor).usingColorSpace(.sRGB)?.cgColor
        context.coordinator.scene?.onCameraChange = onCameraChange
        context.coordinator.scene?.updateScene(
            layout: layout,
            legend: legend,
            visitors: visitors,
            densityCells: densityCells,
            walkingRoutesGrid: walkingRoutesGrid,
            showHeatmap: showHeatmap,
            overlayStyle: overlayStyle
        )
        if let zoomRequest, context.coordinator.lastZoomRequestID != zoomRequest.id {
            context.coordinator.lastZoomRequestID = zoomRequest.id
            let factor: CGFloat = zoomRequest.direction == .zoomIn ? 0.8 : 1.25
            context.coordinator.scene?.zoomCamera(by: factor)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: Venue2DScene?
        var lastZoomRequestID: Int?
    }
}

/// Custom SKView that forwards mouse drag, scroll wheel, and trackpad pinch gestures to the 2D scene camera.
final class InteractiveSKView: SKView {
    weak var venueScene: Venue2DScene?

    override func layout() {
        super.layout()
        venueScene?.ensureCameraFitted(viewSize: bounds.size)
    }

    override func mouseDragged(with event: NSEvent) {
        venueScene?.panCamera(deltaX: event.deltaX, deltaY: event.deltaY)
    }

    override func scrollWheel(with event: NSEvent) {
        guard abs(event.scrollingDeltaY) > 0.01 else { return }
        let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.008 : 0.04
        let factor = max(0.88, min(1.12, 1.0 + event.scrollingDeltaY * sensitivity))
        venueScene?.zoomCamera(by: factor)
    }

    override func magnify(with event: NSEvent) {
        let factor = max(0.85, min(1.15, 1.0 - event.magnification))
        venueScene?.zoomCamera(by: factor)
    }
}

/// Simple SpriteKit scene that draws the 2D bazaar floor, booths, smooth radial heatmap texture, and visitors.
final class Venue2DScene: SKScene {
    private let pointsPerMetre: CGFloat = SpriteCameraTransform.pointsPerMetre
    private var currentLayout: Layout?
    private var currentLegend: Legend = Legend()
    private var hasFittedCamera = false
    private var baseFitScale: CGFloat = 1.0
    var onCameraChange: ((SpriteCameraTransform) -> Void)?

    private let cameraNode = SKCameraNode()
    private let floorLayer = SKNode()
    private let heatmapSprite = SKSpriteNode()
    private let objectLayer = SKNode()
    private let visitorLayer = SKNode()
    private var visitorNodes: [Int: SKSpriteNode] = [:]
    private var lastHeatmapCells: [DensityCell] = []
    private var lastWalkingRoutesGrid: WalkingRoutesGrid?
    private var lastOverlayStyle: Simulation2DSpriteView.OverlayStyle = .heatmap
    private lazy var visitorDotTexture = VisitorDots.makeTexture()
    private static let footfallRamp: [SIMD3<Double>] = (0..<256).map { step in
        let color = NSColor(HeatScale.footfallColor(forLevel: Double(step) / 255.0)).usingColorSpace(.sRGB) ?? .systemGreen
        return SIMD3(Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent))
    }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        camera = cameraNode
        floorLayer.zPosition = 0
        heatmapSprite.zPosition = 1
        objectLayer.zPosition = 2
        visitorLayer.zPosition = 3

        addChild(cameraNode)
        addChild(floorLayer)
        addChild(heatmapSprite)
        addChild(objectLayer)
        addChild(visitorLayer)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        ensureCameraFitted(viewSize: size)
    }

    func ensureCameraFitted(viewSize: CGSize) {
        guard !hasFittedCamera, let layout = currentLayout,
              viewSize.width > 80, viewSize.height > 80 else {
            return
        }
        fitCamera(to: layout, viewSize: viewSize)
        hasFittedCamera = true
    }

    func updateScene(
        layout: Layout,
        legend: Legend = Legend(),
        visitors: [SimulatedVisitor],
        densityCells: [DensityCell],
        walkingRoutesGrid: WalkingRoutesGrid? = nil,
        showHeatmap: Bool,
        overlayStyle: Simulation2DSpriteView.OverlayStyle = .heatmap
    ) {
        if currentLayout?.id != layout.id || currentLegend != legend {
            let layoutChanged = currentLayout?.id != layout.id
            currentLayout = layout
            currentLegend = legend
            rebuildStaticLayout(layout, legend: legend)
            if layoutChanged {
                hasFittedCamera = false
                visitorNodes.removeAll()
                visitorLayer.removeAllChildren()
                lastHeatmapCells = []
                lastWalkingRoutesGrid = nil
                let fallbackSize = (size.width > 80 && size.height > 80) ? size : CGSize(width: 1000, height: 700)
                fitCamera(to: layout, viewSize: fallbackSize)
            }
        }

        ensureCameraFitted(viewSize: size)
        updateSmoothHeatmap(
            cells: densityCells,
            walkingRoutesGrid: walkingRoutesGrid,
            showHeatmap: showHeatmap,
            style: overlayStyle,
            layout: layout
        )
        updateVisitors(visitors, layout: layout)
    }

    // MARK: - Camera Controls (Pan & Zoom)

    func fitCamera(to layout: Layout, viewSize: CGSize) {
        let worldW = CGFloat(max(1.0, layout.sizeM.x)) * pointsPerMetre
        let worldH = CGFloat(max(1.0, layout.sizeM.y)) * pointsPerMetre

        let viewW = max(200, viewSize.width * 0.78)
        let viewH = max(200, viewSize.height * 0.68)
        let scale = max(worldW / viewW, worldH / viewH)
        baseFitScale = max(0.1, scale)
        // Shift camera slightly upward in SpriteKit coordinates so the venue sits below the top overlay pill.
        let verticalOffsetPt: CGFloat = 28
        cameraNode.position = CGPoint(x: worldW / 2, y: worldH / 2 + verticalOffsetPt * baseFitScale)
        cameraNode.setScale(baseFitScale)
        publishCameraTransform(viewSize: viewSize)
    }

    func panCamera(deltaX: CGFloat, deltaY: CGFloat) {
        let currentScale = cameraNode.xScale
        cameraNode.position.x -= deltaX * currentScale
        cameraNode.position.y += deltaY * currentScale
        publishCameraTransform(viewSize: size)
    }

    func zoomCamera(by factor: CGFloat) {
        let minScale = baseFitScale * 0.25
        let maxScale = baseFitScale * 3.0
        let newScale = min(maxScale, max(minScale, cameraNode.xScale * factor))
        cameraNode.setScale(newScale)
        publishCameraTransform(viewSize: size)
    }

    private func publishCameraTransform(viewSize: CGSize) {
        let transform = SpriteCameraTransform(
            cameraPosition: cameraNode.position,
            cameraScale: cameraNode.xScale,
            viewSize: viewSize
        )
        DispatchQueue.main.async { [weak self] in
            self?.onCameraChange?(transform)
        }
    }

    private func toScene(_ point: SIMD2<Double>, in layout: Layout) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * pointsPerMetre,
            y: CGFloat(layout.sizeM.y - point.y) * pointsPerMetre
        )
    }

    // MARK: - Static Floor & Booths

    private static func srgbColor(_ rgba: SIMD4<Float>) -> NSColor {
        NSColor(srgbRed: CGFloat(rgba.x), green: CGFloat(rgba.y), blue: CGFloat(rgba.z), alpha: CGFloat(rgba.w))
    }

    private func rebuildStaticLayout(_ layout: Layout, legend: Legend) {
        floorLayer.removeAllChildren()
        objectLayer.removeAllChildren()

        let floorColor = Self.srgbColor(VenueGeometry.hallFloorColor)
        let borderColor = Self.srgbColor(VenueGeometry.frameColor)

        if layout.hall.count >= 3 {
            floorLayer.addChild(makePolygonNode(points: layout.hall, in: layout, fill: floorColor, stroke: borderColor))
        } else {
            let rect = CGRect(
                x: 0,
                y: 0,
                width: CGFloat(layout.sizeM.x) * pointsPerMetre,
                height: CGFloat(layout.sizeM.y) * pointsPerMetre
            )
            let box = SKShapeNode(rect: rect)
            box.fillColor = floorColor
            box.strokeColor = borderColor
            box.lineWidth = 1.5
            floorLayer.addChild(box)
        }

        if layout.lobby.count >= 3 {
            let lobbyColor = Self.srgbColor(VenueGeometry.lobbyFloorColor)
            floorLayer.addChild(makePolygonNode(points: layout.lobby, in: layout, fill: lobbyColor, stroke: borderColor))
        }

        for object in layout.objects {
            objectLayer.addChild(makeObjectNode(for: object, in: layout, legend: legend))
        }
    }

    private func makePolygonNode(
        points: [SIMD2<Double>],
        in layout: Layout,
        fill: NSColor,
        stroke: NSColor
    ) -> SKShapeNode {
        let path = CGMutablePath()
        if let first = points.first {
            path.move(to: toScene(first, in: layout))
            for point in points.dropFirst() {
                path.addLine(to: toScene(point, in: layout))
            }
            path.closeSubpath()
        }
        let node = SKShapeNode(path: path)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = 1.5
        return node
    }

    private func makeObjectNode(for object: LayoutObject, in layout: Layout, legend: Legend) -> SKShapeNode {
        let size = CGSize(
            width: CGFloat(object.placement.sizeM.x) * pointsPerMetre,
            height: CGFloat(object.placement.sizeM.y) * pointsPerMetre
        )
        let inkColor = Self.srgbColor(VenueGeometry.frameColor)
        let node: SKShapeNode
        if object.kind == .table {
            let model = FurnitureModels.table(object.catalogID)
            let isRound = model.map { $0.shape == .round } ?? (object.placement.shape == .round)
            if isRound {
                let diameter = min(size.width, size.height)
                node = SKShapeNode(ellipseOf: CGSize(width: diameter, height: diameter))
            } else {
                node = SKShapeNode(rectOf: size, cornerRadius: 2)
            }
        } else if object.kind == .block, object.isColumn {
            let diameter = min(size.width, size.height)
            node = SKShapeNode(ellipseOf: CGSize(width: diameter, height: diameter))
        } else {
            node = SKShapeNode(rectOf: size, cornerRadius: 2)
        }

        node.position = toScene(object.placement.center, in: layout)
        node.zRotation = CGFloat(-object.placement.rotationRadians)
        node.strokeColor = inkColor
        node.lineWidth = 1.2

        switch object.kind {
        case .booth:
            node.fillColor = TenantColors.boothNSColor(for: object, legend: legend)
            node.zPosition = 1
        case .table:
            node.fillColor = Self.srgbColor(VenueGeometry.yellowColor)
            node.zPosition = 1
        case .seating:
            node.fillColor = Self.srgbColor(VenueGeometry.paleBlueColor)
            node.zPosition = 1
            addSeatingChairNodes(to: node, for: object, inkColor: inkColor)
        case .entertainment:
            node.fillColor = Self.srgbColor(VenueGeometry.entertainmentColor(for: object))
            node.zPosition = 1
        case .door:
            node.fillColor = Self.srgbColor(VenueGeometry.doorColor(for: object))
            node.zPosition = 2
        case .wall:
            node.fillColor = Self.srgbColor(VenueGeometry.whiteColor)
            node.lineWidth = 1.4
            node.zPosition = 0
        case .block where object.isColumn:
            node.fillColor = Self.srgbColor(VenueGeometry.cobaltColor)
            node.zPosition = 1
        case .block:
            node.fillColor = Self.srgbColor(VenueGeometry.blockColor)
            node.zPosition = 1
        case .closedArea:
            node.fillColor = Self.srgbColor(VenueGeometry.paleBlueColor)
            node.zPosition = 0
        }
        return node
    }

    private func addSeatingChairNodes(to parent: SKNode, for object: LayoutObject, inkColor: NSColor) {
        let chairSide = CGFloat(FurnitureModels.chairSizeM.x) * pointsPerMetre
        let chairSize = CGSize(width: chairSide, height: chairSide)
        let chairFill = Self.srgbColor(VenueGeometry.creamColor)
        for offset in FurnitureModels.gridOffsets(for: object.placement.sizeM) {
            let chair = SKShapeNode(rectOf: chairSize, cornerRadius: 1)
            chair.position = CGPoint(
                x: CGFloat(offset.x) * pointsPerMetre,
                y: CGFloat(-offset.y) * pointsPerMetre
            )
            chair.fillColor = chairFill
            chair.strokeColor = inkColor
            chair.lineWidth = 0.8
            parent.addChild(chair)
        }
    }

    // MARK: - Smooth Radial Heatmap Overlay (Matching 3D View)

    private func updateSmoothHeatmap(
        cells: [DensityCell],
        walkingRoutesGrid: WalkingRoutesGrid?,
        showHeatmap: Bool,
        style: Simulation2DSpriteView.OverlayStyle,
        layout: Layout
    ) {
        if style == .walkingRoutes, let grid = walkingRoutesGrid {
            guard showHeatmap, grid.columns > 0, grid.rows > 0, grid.values.contains(where: { $0 > 0 }) else {
                heatmapSprite.isHidden = true
                return
            }
            heatmapSprite.isHidden = false
            guard grid != lastWalkingRoutesGrid || style != lastOverlayStyle else { return }
            lastWalkingRoutesGrid = grid
            lastOverlayStyle = style
            guard let cgImage = renderWalkingRoutesCGImage(for: layout, grid: grid) else {
                heatmapSprite.isHidden = true
                return
            }
            applyOverlayTexture(cgImage, for: layout)
            return
        }

        guard showHeatmap, !cells.isEmpty else {
            heatmapSprite.isHidden = true
            return
        }
        heatmapSprite.isHidden = false
        guard cells != lastHeatmapCells || style != lastOverlayStyle else { return }
        lastHeatmapCells = cells
        lastOverlayStyle = style
        guard let cgImage = renderSmoothHeatmapCGImage(for: layout, cells: cells, style: style) else {
            heatmapSprite.isHidden = true
            return
        }
        applyOverlayTexture(cgImage, for: layout)
    }

    private func applyOverlayTexture(_ cgImage: CGImage, for layout: Layout) {
        let worldW = CGFloat(max(1.0, layout.sizeM.x)) * pointsPerMetre
        let worldH = CGFloat(max(1.0, layout.sizeM.y)) * pointsPerMetre
        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .linear

        heatmapSprite.texture = texture
        heatmapSprite.size = CGSize(width: worldW, height: worldH)
        heatmapSprite.position = CGPoint(x: worldW / 2, y: worldH / 2)
    }

    /// Renders a continuous bilinearly-interpolated walking routes ribbon texture so paths appear smooth and line-like
    /// rather than discrete grid dots.
    private func renderWalkingRoutesCGImage(for layout: Layout, grid: WalkingRoutesGrid) -> CGImage? {
        let pixelsPerMetre = 6.0
        let texWidth = max(10, Int(ceil(layout.sizeM.x * pixelsPerMetre)))
        let texHeight = max(10, Int(ceil(layout.sizeM.y * pixelsPerMetre)))
        let cols = grid.columns
        let rows = grid.rows
        let tileM = max(grid.tileM, 0.05)
        guard grid.values.count == cols * rows else { return nil }

        var pixels = [UInt8](repeating: 0, count: texWidth * texHeight * 4)
        for py in 0..<texHeight {
            let worldY = (Double(py) + 0.5) / pixelsPerMetre
            let gy = (worldY - grid.origin.y) / tileM - 0.5
            guard gy >= -0.5, gy <= Double(rows) - 0.5 else { continue }
            let y0 = min(max(Int(floor(gy)), 0), rows - 1)
            let y1 = min(y0 + 1, rows - 1)
            let ty = min(max(gy - Double(y0), 0), 1)
            let row0 = y0 * cols
            let row1 = y1 * cols

            for px in 0..<texWidth {
                let worldX = (Double(px) + 0.5) / pixelsPerMetre
                let gx = (worldX - grid.origin.x) / tileM - 0.5
                guard gx >= -0.5, gx <= Double(cols) - 0.5 else { continue }
                let x0 = min(max(Int(floor(gx)), 0), cols - 1)
                let x1 = min(x0 + 1, cols - 1)
                let tx = min(max(gx - Double(x0), 0), 1)

                let top = grid.values[row0 + x0] * (1 - tx) + grid.values[row0 + x1] * tx
                let bottom = grid.values[row1 + x0] * (1 - tx) + grid.values[row1 + x1] * tx
                let level = min(max(top * (1 - ty) + bottom * ty, 0), 1)
                guard level > 0.015 else { continue }

                let fade = min(max((level - 0.015) / 0.04, 0), 1)
                let alpha = HeatScale.footfallAlpha(forLevel: level) * (fade * fade * (3 - 2 * fade))
                guard alpha > 0.005 else { continue }

                let rgb = Self.footfallRamp[min(max(Int(level * 255.0 + 0.5), 0), 255)]
                let index = (py * texWidth + px) * 4
                pixels[index] = UInt8(min(rgb.x * alpha, 1) * 255 + 0.5)
                pixels[index + 1] = UInt8(min(rgb.y * alpha, 1) * 255 + 0.5)
                pixels[index + 2] = UInt8(min(rgb.z * alpha, 1) * 255 + 0.5)
                pixels[index + 3] = UInt8(min(alpha, 1) * 255 + 0.5)
            }
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return pixels.withUnsafeMutableBytes { rawBuffer -> CGImage? in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: texWidth,
                height: texHeight,
                bitsPerComponent: 8,
                bytesPerRow: texWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }
            clearObstacleFootprints(in: context, layout: layout, pixelsPerMetre: pixelsPerMetre)
            return context.makeImage()
        }
    }

    private func clearObstacleFootprints(in context: CGContext, layout: Layout, pixelsPerMetre: Double) {
        context.setBlendMode(.clear)
        for object in layout.objects where object.kind.blocksWalking {
            let centerX = CGFloat(object.placement.center.x * pixelsPerMetre)
            let centerY = CGFloat((layout.sizeM.y - object.placement.center.y) * pixelsPerMetre)
            let width = CGFloat(object.placement.sizeM.x * pixelsPerMetre)
            let height = CGFloat(object.placement.sizeM.y * pixelsPerMetre)
            context.saveGState()
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: CGFloat(-object.placement.rotationRadians))
            context.fill(CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
            context.restoreGState()
        }
    }

    private func renderSmoothHeatmapCGImage(
        for layout: Layout,
        cells: [DensityCell],
        style: Simulation2DSpriteView.OverlayStyle
    ) -> CGImage? {
        let pixelsPerMetre = 5.0
        let texWidth = max(10, Int(ceil(layout.sizeM.x * pixelsPerMetre)))
        let texHeight = max(10, Int(ceil(layout.sizeM.y * pixelsPerMetre)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: texWidth,
            height: texHeight,
            bitsPerComponent: 8,
            bytesPerRow: texWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let blobRadiusPx = CGFloat((style == .walkingRoutes ? 0.95 : 1.35) * pixelsPerMetre)
        let sortedCells = cells.sorted { $0.peoplePerSquareMetre < $1.peoplePerSquareMetre }

        for cell in sortedCells {
            let center = CGPoint(
                x: CGFloat(cell.center.x * pixelsPerMetre),
                y: CGFloat((layout.sizeM.y - cell.center.y) * pixelsPerMetre)
            )
            let rgb: (r: CGFloat, g: CGFloat, b: CGFloat)
            let peakAlpha: CGFloat
            switch style {
            case .heatmap:
                rgb = heatmapRGB(for: cell.peoplePerSquareMetre)
                let normalized = min(max((cell.peoplePerSquareMetre - 0.04) / 1.25, 0.0), 1.0)
                peakAlpha = CGFloat(0.06 + 0.84 * pow(normalized, 0.85))
            case .walkingRoutes:
                let level = min(max(cell.peoplePerSquareMetre, 0), 1)
                rgb = walkingRouteRGB(for: level)
                peakAlpha = CGFloat(HeatScale.footfallAlpha(forLevel: level))
            }

            let colors = [
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: peakAlpha),
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: peakAlpha * 0.58),
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 0.0)
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.45, 1.0]

            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
                context.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: blobRadiusPx,
                    options: []
                )
            }
        }

        // Clear booth and obstacle footprints from the heatmap texture so it never bleeds into booths
        context.setBlendMode(.clear)
        for object in layout.objects where object.kind.blocksWalking {
            let centerX = CGFloat(object.placement.center.x * pixelsPerMetre)
            let centerY = CGFloat((layout.sizeM.y - object.placement.center.y) * pixelsPerMetre)
            let width = CGFloat(object.placement.sizeM.x * pixelsPerMetre)
            let height = CGFloat(object.placement.sizeM.y * pixelsPerMetre)
            context.saveGState()
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: CGFloat(-object.placement.rotationRadians))
            context.fill(CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
            context.restoreGState()
        }

        return context.makeImage()
    }

    private func walkingRouteRGB(for level: Double) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let color = NSColor(HeatScale.footfallColor(forLevel: level)).usingColorSpace(.sRGB) ?? .systemGreen
        return (color.redComponent, color.greenComponent, color.blueComponent)
    }

    private func heatmapRGB(for density: Double) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if density >= 1.60 {
            return (0.86, 0.06, 0.20)
        } else if density >= 1.15 {
            return (1.0, 0.20, 0.14)
        } else if density >= 0.82 {
            return (1.0, 0.52, 0.10)
        } else if density >= 0.55 {
            return (0.98, 0.84, 0.18)
        } else if density >= 0.20 {
            return (0.22, 0.84, 0.44)
        } else {
            return (0.20, 0.76, 0.85)
        }
    }

    // MARK: - Smooth Visitor Movement

    private func updateVisitors(_ visitors: [SimulatedVisitor], layout: Layout) {
        let activeIDs = Set(visitors.map(\.id))

        for (id, node) in visitorNodes where !activeIDs.contains(id) {
            node.removeFromParent()
            visitorNodes.removeValue(forKey: id)
        }

        let dotSize = CGSize(width: pointsPerMetre * 0.56, height: pointsPerMetre * 0.56)
        for visitor in visitors {
            let targetPos = toScene(visitor.position, in: layout)
            let color = VisitorDots.color(for: visitor.state)

            if let existing = visitorNodes[visitor.id] {
                existing.position = targetPos
                if existing.color != color { existing.color = color }
            } else {
                let created = SKSpriteNode(texture: visitorDotTexture, size: dotSize)
                created.colorBlendFactor = 1
                created.color = color
                created.position = targetPos
                visitorLayer.addChild(created)
                visitorNodes[visitor.id] = created
            }
        }
    }
}
