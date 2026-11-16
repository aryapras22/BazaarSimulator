import AppKit
import CoreGraphics
import SpriteKit
import SwiftUI
import simd

/// A lightweight 2D SpriteKit view that renders the venue floor plan, smooth radial heatmap, and moving visitors.
/// Supports dragging to pan/scroll and scrolling or pinching to zoom.
struct Simulation2DSpriteView: NSViewRepresentable {
    let layout: Layout
    var visitors: [SimulatedVisitor] = []
    var densityCells: [DensityCell] = []
    var showHeatmap = false

    func makeNSView(context: Context) -> InteractiveSKView {
        let skView = InteractiveSKView()
        skView.ignoresSiblingOrder = false
        skView.preferredFramesPerSecond = 60
        let scene = Venue2DScene(size: CGSize(width: 1000, height: 700))
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        skView.venueScene = scene
        context.coordinator.scene = scene
        return skView
    }

    func updateNSView(_ skView: InteractiveSKView, context: Context) {
        context.coordinator.scene?.updateScene(
            layout: layout,
            visitors: visitors,
            densityCells: densityCells,
            showHeatmap: showHeatmap
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: Venue2DScene?
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
    private let pointsPerMetre: CGFloat = 20.0
    private var currentLayout: Layout?
    private var hasFittedCamera = false
    private var baseFitScale: CGFloat = 1.0

    private let cameraNode = SKCameraNode()
    private let floorLayer = SKNode()
    private let heatmapSprite = SKSpriteNode()
    private let objectLayer = SKNode()
    private let visitorLayer = SKNode()
    private var visitorNodes: [Int: SKSpriteNode] = [:]
    private var lastHeatmapCells: [DensityCell] = []
    private lazy var visitorDotTexture = VisitorDots.makeTexture()

    override func didMove(to view: SKView) {
        backgroundColor = NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.14, alpha: 1.0)
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
        visitors: [SimulatedVisitor],
        densityCells: [DensityCell],
        showHeatmap: Bool
    ) {
        if currentLayout?.id != layout.id {
            currentLayout = layout
            hasFittedCamera = false
            rebuildStaticLayout(layout)
            visitorNodes.removeAll()
            visitorLayer.removeAllChildren()
            lastHeatmapCells = []
            let fallbackSize = (size.width > 80 && size.height > 80) ? size : CGSize(width: 1000, height: 700)
            fitCamera(to: layout, viewSize: fallbackSize)
        }

        ensureCameraFitted(viewSize: size)
        updateSmoothHeatmap(cells: densityCells, showHeatmap: showHeatmap, layout: layout)
        updateVisitors(visitors, layout: layout)
    }

    // MARK: - Camera Controls (Pan & Zoom)

    func fitCamera(to layout: Layout, viewSize: CGSize) {
        let worldW = CGFloat(max(1.0, layout.sizeM.x)) * pointsPerMetre
        let worldH = CGFloat(max(1.0, layout.sizeM.y)) * pointsPerMetre
        cameraNode.position = CGPoint(x: worldW / 2, y: worldH / 2)

        let viewW = max(200, viewSize.width * 0.78)
        let viewH = max(200, viewSize.height * 0.75)
        let scale = max(worldW / viewW, worldH / viewH)
        baseFitScale = max(0.1, scale)
        cameraNode.setScale(baseFitScale)
    }

    func panCamera(deltaX: CGFloat, deltaY: CGFloat) {
        let currentScale = cameraNode.xScale
        cameraNode.position.x -= deltaX * currentScale
        cameraNode.position.y += deltaY * currentScale
    }

    func zoomCamera(by factor: CGFloat) {
        let minScale = baseFitScale * 0.25
        let maxScale = baseFitScale * 3.0
        let newScale = min(maxScale, max(minScale, cameraNode.xScale * factor))
        cameraNode.setScale(newScale)
    }

    private func toScene(_ point: SIMD2<Double>, in layout: Layout) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x) * pointsPerMetre,
            y: CGFloat(layout.sizeM.y - point.y) * pointsPerMetre
        )
    }

    // MARK: - Static Floor & Booths

    private func rebuildStaticLayout(_ layout: Layout) {
        floorLayer.removeAllChildren()
        objectLayer.removeAllChildren()

        let floorColor = NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.23, alpha: 1.0)
        let borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.22)

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
            let lobbyColor = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.20, alpha: 1.0)
            floorLayer.addChild(makePolygonNode(points: layout.lobby, in: layout, fill: lobbyColor, stroke: borderColor))
        }

        for object in layout.objects {
            objectLayer.addChild(makeObjectNode(for: object, in: layout))
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

    private func makeObjectNode(for object: LayoutObject, in layout: Layout) -> SKShapeNode {
        let size = CGSize(
            width: CGFloat(object.placement.sizeM.x) * pointsPerMetre,
            height: CGFloat(object.placement.sizeM.y) * pointsPerMetre
        )
        let node = object.kind == .table
            ? SKShapeNode(ellipseOf: size)
            : SKShapeNode(rectOf: size, cornerRadius: 2)

        node.position = toScene(object.placement.center, in: layout)
        node.zRotation = CGFloat(-object.placement.rotationRadians)
        node.lineWidth = 1.0

        switch object.kind {
        case .booth:
            node.fillColor = NSColor(calibratedRed: 0.22, green: 0.44, blue: 0.74, alpha: 1.0)
            node.strokeColor = NSColor(calibratedWhite: 1.0, alpha: 0.55)
        case .table:
            node.fillColor = NSColor(calibratedRed: 0.35, green: 0.38, blue: 0.45, alpha: 1.0)
            node.strokeColor = .clear
        case .seating:
            node.fillColor = NSColor(calibratedRed: 0.35, green: 0.24, blue: 0.50, alpha: 0.75)
            node.strokeColor = .clear
        case .entertainment:
            node.fillColor = NSColor(calibratedRed: 0.90, green: 0.55, blue: 0.20, alpha: 1.0)
            node.strokeColor = NSColor(calibratedWhite: 1.0, alpha: 0.55)
        case .door:
            let isExit = object.doorFlow?.direction == .exit
            node.fillColor = isExit ? NSColor.systemRed : NSColor.systemGreen
            node.strokeColor = .clear
        case .wall, .block, .closedArea:
            node.fillColor = NSColor(calibratedRed: 0.28, green: 0.32, blue: 0.40, alpha: 1.0)
            node.strokeColor = .clear
        }
        return node
    }

    // MARK: - Smooth Radial Heatmap Overlay (Matching 3D View)

    private func updateSmoothHeatmap(cells: [DensityCell], showHeatmap: Bool, layout: Layout) {
        guard showHeatmap, !cells.isEmpty else {
            heatmapSprite.isHidden = true
            return
        }
        heatmapSprite.isHidden = false
        guard cells != lastHeatmapCells else { return }
        lastHeatmapCells = cells
        guard let cgImage = renderSmoothHeatmapCGImage(for: layout, cells: cells) else {
            heatmapSprite.isHidden = true
            return
        }

        let worldW = CGFloat(max(1.0, layout.sizeM.x)) * pointsPerMetre
        let worldH = CGFloat(max(1.0, layout.sizeM.y)) * pointsPerMetre
        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .linear

        heatmapSprite.texture = texture
        heatmapSprite.size = CGSize(width: worldW, height: worldH)
        heatmapSprite.position = CGPoint(x: worldW / 2, y: worldH / 2)
    }

    private func renderSmoothHeatmapCGImage(for layout: Layout, cells: [DensityCell]) -> CGImage? {
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

        let blobRadiusPx = CGFloat(1.65 * pixelsPerMetre)

        for cell in cells {
            let center = CGPoint(
                x: CGFloat(cell.center.x * pixelsPerMetre),
                y: CGFloat((layout.sizeM.y - cell.center.y) * pixelsPerMetre)
            )
            let rgb = heatmapRGB(for: cell.peoplePerSquareMetre)
            let peakAlpha = CGFloat(min(0.74, max(0.14, cell.peoplePerSquareMetre / 1.15)))

            let colors = [
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: peakAlpha),
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: peakAlpha * 0.52),
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

    private func heatmapRGB(for density: Double) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if density > 1.80 {
            return (0.85, 0.08, 0.22)
        } else if density >= 0.72 {
            return (1.0, 0.24, 0.20)
        } else if density >= 0.45 {
            return (1.0, 0.55, 0.12)
        } else if density >= 0.27 {
            return (0.98, 0.84, 0.18)
        } else if density >= 0.08 {
            return (0.22, 0.86, 0.45)
        } else {
            return (0.20, 0.78, 0.85)
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
