import Foundation
import SwiftUI
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelViewsTests {

    private static func makeViewModel() -> LayoutEditorViewModel {
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        return viewModel
    }

    private static func makeSingleBoothLayout(
        attractiveness: Double,
        label: String = ""
    ) -> (BazaarSimulator.Layout, LayoutObject) {
        let booth = LayoutObject(
            kind: .booth,
            label: label,
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(4, 4)),
            openSides: .all,
            attractiveness: attractiveness
        )
        let layout = BazaarSimulator.Layout(
            name: "Single Booth",
            sizeM: SIMD2<Double>(10, 10),
            objects: [booth]
        )
        return (layout, booth)
    }

    private static func renderCanvas(
        snapshot: CanvasDisplaySnapshot,
        size: CGSize,
        scale: Double = 20
    ) throws -> CanvasPixelBuffer {
        let transform = CanvasTransform(scale: scale, offset: .zero)
        let view = Canvas { context, canvasSize in
            CanvasSceneRenderer.draw(
                in: &context,
                size: canvasSize,
                snapshot: snapshot,
                transform: transform,
                drag: CanvasDragState()
            )
        }
        .frame(width: size.width, height: size.height)
        return try CanvasPixelBuffer.render(view)
    }

    @Test("The attractiveness scale clamps values outside 1 to 5")
    func attractivenessScaleClamps() {
        #expect(AttractivenessScale.fraction(of: -3) == 0)
        #expect(AttractivenessScale.fraction(of: 3) == 0.5)
        #expect(AttractivenessScale.fraction(of: 40) == 1)
    }

    @Test("A resize refits the canvas until the user zooms or pans")
    func resizeRefitsOnlyWhileUntouched() {
        let viewModel = Self.makeViewModel()
        let layoutSize = viewModel.layout.sizeM
        viewModel.fitToView(in: SIMD2<Double>(960, 640))

        viewModel.refitIfUntouched(in: SIMD2<Double>(1400, 900))
        #expect(viewModel.transform == CanvasTransform.fitting(layoutSize: layoutSize, in: SIMD2<Double>(1400, 900)))

        viewModel.transform = viewModel.transform.panned(by: SIMD2<Double>(20, 0))
        let panned = viewModel.transform
        viewModel.refitIfUntouched(in: SIMD2<Double>(600, 400))
        #expect(viewModel.transform == panned)
    }

    @Test("Booths on the Floor Plan layer use default fill instead of attractiveness heat colours by default")
    func defaultBoothsRenderWithoutAttractivenessHeat() throws {
        let lowBooth = LayoutObject(
            kind: .booth,
            label: "",
            placement: Placement(center: SIMD2<Double>(4, 5), sizeM: SIMD2<Double>(4, 4)),
            openSides: .all,
            attractiveness: 1
        )
        let highBooth = LayoutObject(
            kind: .booth,
            label: "",
            placement: Placement(center: SIMD2<Double>(10, 5), sizeM: SIMD2<Double>(4, 4)),
            openSides: .all,
            attractiveness: 5
        )
        let layout = BazaarSimulator.Layout(
            name: "Attractiveness Default",
            sizeM: SIMD2<Double>(16, 10),
            objects: [lowBooth, highBooth]
        )
        let snapshot = CanvasDisplaySnapshot(
            layout: layout,
            legend: Legend(),
            activeLayer: .booths
        )

        let buffer = try Self.renderCanvas(snapshot: snapshot, size: CGSize(width: 320, height: 200))
        let expectedFill = CanvasRGBA(color: Palette.canvasBoothFill)
        let lowHeat = CanvasRGBA(color: AttractivenessScale.color(for: 1))
        let highHeat = CanvasRGBA(color: AttractivenessScale.color(for: 5))

        let lowCenter = buffer.pixel(col: 80, row: 100)
        let highCenter = buffer.pixel(col: 200, row: 100)
        let highCorner = buffer.pixel(col: 166, row: 66)

        #expect(lowCenter.isClose(to: expectedFill))
        #expect(!lowCenter.isClose(to: lowHeat))
        #expect(highCenter.isClose(to: expectedFill))
        #expect(!highCenter.isClose(to: highHeat))
        #expect(highCorner.isClose(to: expectedFill))
    }

    @Test("A selected booth on the Floor Plan layer uses selection fill when attractiveness colouring is off")
    func selectedBoothUsesSelectionFillByDefault() throws {
        let (layout, booth) = Self.makeSingleBoothLayout(attractiveness: 5)
        let snapshot = CanvasDisplaySnapshot(
            layout: layout,
            legend: Legend(),
            activeLayer: .booths,
            selectionID: booth.id
        )

        let buffer = try Self.renderCanvas(snapshot: snapshot, size: CGSize(width: 200, height: 200))
        let center = buffer.pixel(col: 100, row: 100)

        #expect(center.isClose(to: CanvasRGBA(color: Palette.canvasSelection)))
        #expect(!center.isClose(to: CanvasRGBA(color: AttractivenessScale.color(for: 5))))
    }

    @Test("An unselected high-attractiveness booth uses dark line label colour on light booth fill by default")
    func unselectedHighAttractivenessBoothUsesDarkLabelByDefault() throws {
        let (layout, _) = Self.makeSingleBoothLayout(attractiveness: 5, label: "B8")
        let snapshot = CanvasDisplaySnapshot(
            layout: layout,
            legend: Legend(),
            activeLayer: .booths
        )

        let buffer = try Self.renderCanvas(snapshot: snapshot, size: CGSize(width: 200, height: 200))
        let interior = buffer.pixel(col: 70, row: 70)
        let labelRect = CGRect(x: 80, y: 85, width: 40, height: 30)
        let hasDarkBlueLabel = buffer.containsDarkBlueLabelPixel(in: labelRect)

        #expect(interior.isClose(to: CanvasRGBA(color: Palette.canvasBoothFill)))
        #expect(hasDarkBlueLabel)
    }

    @Test("Attractiveness filter defaults to off and toggles on and back off")
    func attractivenessToggleDefaultsOffAndToggles() {
        let viewModel = Self.makeViewModel()
        #expect(!viewModel.showsAttractiveness)

        viewModel.toggleAttractiveness()
        #expect(viewModel.showsAttractiveness)

        viewModel.toggleAttractiveness()
        #expect(!viewModel.showsAttractiveness)
    }

    @Test("CanvasDisplaySnapshot defaults showsAttractiveness to false")
    func canvasDisplaySnapshotDefaultsAttractivenessOff() {
        let (layout, _) = Self.makeSingleBoothLayout(attractiveness: 5)
        let snapshot = CanvasDisplaySnapshot(layout: layout, legend: Legend(), activeLayer: .booths)
        #expect(!snapshot.showsAttractiveness)
    }

    @Test("CanvasSceneRenderer enables attractiveness heat only when filter is on in the booths layer")
    func attractivenessDisplayMatchesLayerAndToggle() {
        let (layout, _) = Self.makeSingleBoothLayout(attractiveness: 5)

        let boothsOff = CanvasDisplaySnapshot(
            layout: layout,
            legend: Legend(),
            activeLayer: .booths,
            showsAttractiveness: false
        )
        let boothsOn = CanvasDisplaySnapshot(
            layout: layout,
            legend: Legend(),
            activeLayer: .booths,
            showsAttractiveness: true
        )
        let structureOn = CanvasDisplaySnapshot(
            layout: layout,
            legend: Legend(),
            activeLayer: .structure,
            showsAttractiveness: true
        )

        #expect(CanvasSceneRenderer.attractivenessDisplay(for: boothsOff) == .hidden)
        #expect(CanvasSceneRenderer.attractivenessDisplay(for: boothsOn) == .heat)
        #expect(CanvasSceneRenderer.attractivenessDisplay(for: structureOn) == .hidden)
    }
}

private struct CanvasRGBA: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let resolved = color.resolve(in: EnvironmentValues())
        let byte: (Float) -> UInt8 = { UInt8(min(max((Double($0) * 255.0).rounded(), 0), 255)) }
        self.init(
            red: byte(resolved.red),
            green: byte(resolved.green),
            blue: byte(resolved.blue),
            alpha: byte(resolved.opacity)
        )
    }

    func isClose(to other: CanvasRGBA, tolerance: Int = 10) -> Bool {
        abs(Int(red) - Int(other.red)) <= tolerance
            && abs(Int(green) - Int(other.green)) <= tolerance
            && abs(Int(blue) - Int(other.blue)) <= tolerance
            && abs(Int(alpha) - Int(other.alpha)) <= tolerance
    }
}

@MainActor
private struct CanvasPixelBuffer {
    let bytes: [UInt8]
    let width: Int
    let height: Int

    static func render<V: View>(_ view: V) throws -> CanvasPixelBuffer {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        let image = try #require(renderer.cgImage)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: &bytes,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return CanvasPixelBuffer(bytes: bytes, width: image.width, height: image.height)
    }

    func pixel(col: Int, row: Int) -> CanvasRGBA {
        let offset = (row * width + col) * 4
        return CanvasRGBA(
            red: bytes[offset],
            green: bytes[offset + 1],
            blue: bytes[offset + 2],
            alpha: bytes[offset + 3]
        )
    }

    func containsDarkBlueLabelPixel(in rect: CGRect) -> Bool {
        for row in Int(rect.minY)..<Int(rect.maxY) {
            for col in Int(rect.minX)..<Int(rect.maxX) {
                let sample = pixel(col: col, row: row)
                if Int(sample.blue) - Int(sample.red) > 30 && sample.red < 150 {
                    return true
                }
            }
        }
        return false
    }
}
