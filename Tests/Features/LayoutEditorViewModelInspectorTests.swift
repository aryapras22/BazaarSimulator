import Foundation
import simd
import SwiftUI
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelInspectorTests {
    @Test("A valid inspector edit applies at once as an undoable edit")
    func inspectorEditAppliesAtOnce() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        #expect(!context.viewModel.canUndo)
        context.viewModel.editInspectorDraft { $0.widthM = 3.5 }

        let edited = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(edited.placement.sizeM.x == 3.5)
        #expect(context.viewModel.canUndo)
    }

    @Test("A booth starts at attractiveness 1, a whole number from 1 to 5 applies and a negative or fractional one does not")
    func attractivenessEdit() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        #expect(booth.attractiveness == 1)

        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.attractiveness = 3 }
        context.viewModel.editInspectorDraft { $0.attractiveness = -1 }
        context.viewModel.editInspectorDraft { $0.attractiveness = 2.5 }

        let edited = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(edited.attractiveness == 3)
    }

    @Test("A block can be made round from the inspector, while a booth stays rectangular")
    func inspectorShapeEdit() throws {
        let structure = LayoutEditorViewModelTests.makeContext(layer: .structure)
        let booths = LayoutEditorViewModelTests.makeContext()
        let block = try #require(structure.layout.objects.first { $0.kind == .block })
        let booth = try #require(booths.layout.objects.first { $0.kind == .booth })

        structure.viewModel.selectObject(block.id)
        structure.viewModel.editInspectorDraft { $0.shape = .round }
        booths.viewModel.selectObject(booth.id)
        booths.viewModel.editInspectorDraft { $0.shape = .round }

        #expect(structure.viewModel.activeLayout?.objects.first { $0.id == block.id }?.placement.shape == .round)
        #expect(booths.viewModel.activeLayout?.objects.first { $0.id == booth.id }?.placement.shape == .rect)
    }

    @Test("A block's label can be edited and titles its inspector, while a column shows no label field")
    func blockLabelEdit() throws {
        let context = LayoutEditorViewModelTests.makeContext(layer: .structure)
        let block = try #require(context.layout.objects.first { $0.kind == .block })

        context.viewModel.selectObject(block.id)
        context.viewModel.editInspectorDraft { $0.label = "Ticket desk" }

        #expect(context.viewModel.activeLayout?.objects.first { $0.id == block.id }?.label == "Ticket desk")
        #expect(context.viewModel.inspectorTitle == "Ticket desk")
    }

    @Test("Several edits to one object undo in one step")
    func inspectorEditsCoalesce() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 3.0 }
        context.viewModel.editInspectorDraft { $0.widthM = 3.5 }
        context.viewModel.editInspectorDraft { $0.label = "Renamed" }
        context.viewModel.undo()

        #expect(context.viewModel.activeLayout == context.layout)
        #expect(!context.viewModel.canUndo)
    }

    @Test("Changing selection keeps the edit already applied")
    func changingSelectionKeepsEdit() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let firstBooth = try #require(booths.first)
        let secondBooth = try #require(booths.dropFirst().first)

        context.viewModel.selectObject(firstBooth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 4.0 }
        context.viewModel.selectObject(secondBooth.id)

        #expect(context.viewModel.selectionID == secondBooth.id)
        let first = try #require(context.viewModel.activeLayout?.objects.first { $0.id == firstBooth.id })
        #expect(first.placement.sizeM.x == 4.0)
    }

    @Test("An invalid size stays in the draft and never reaches the layout")
    func invalidSizeIsNotApplied() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 0.2 }

        #expect(!context.viewModel.isInspectorDraftValid)
        #expect(context.viewModel.activeLayout == context.layout)
    }

    @Test("Toggling the screen-right edge of a booth rotated 90 degrees toggles its own top side")
    func toggleRotatedScreenEdgeMapsToLocalSide() {
        let initial: OpenSides = []

        let updated = initial.toggling(
            screenSide: .right,
            rotationDegrees: 90,
            allowsMultiple: true
        )

        #expect(updated == .top)
    }

    @Test("Use advice applies the suggested direction")
    func useAdviceAppliesDirection() throws {
        let context = LayoutEditorViewModelTests.makeContext(layer: .structure)
        let doorNW = try #require(
            context.layout.objects.first { $0.kind == .door && $0.label == "Door NW" }
        )

        context.viewModel.selectObject(doorNW.id)
        #expect(context.viewModel.currentDoorAdvice?.suggestedDirection == .entrance)

        context.viewModel.applyDoorAdvice()
        #expect(context.viewModel.inspectorDraft?.doorDirection == .entrance)
        let savedDoor = try #require(
            context.viewModel.activeLayout?.objects.first { $0.id == doorNW.id }
        )
        #expect(savedDoor.doorFlow?.direction == .entrance)
    }

    @Test("Selecting an imported booth changes nothing")
    func selectingImportedBoothChangesNothing() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout")
        let layout = MockLayoutMapper.layout(from: dto, legend: PreviewLayouts.sampleLegend)
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session, onBack: {})
        let firstBooth = try #require(layout.objects.first { $0.kind == .booth })

        viewModel.selectObject(firstBooth.id)

        #expect(!viewModel.canUndo)
    }

    @Test("Selecting a blocked area fills the draft")
    func selectingBlockedAreaFillsDraft() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)

        #expect(viewModel.inspectorDraft?.kind == .closedArea)
        #expect(viewModel.inspectorTitle == "Restricted area")
    }

    @Test("Renaming a blocked area applies the label")
    func renamingBlockedAreaAppliesLabel() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)
        viewModel.editInspectorDraft { $0.label = "Storage" }

        #expect(viewModel.selectedObject?.label == "Storage")
    }

    @Test("A blocked area narrower than 0.5 m is not applied")
    func blockedAreaUnderMinimumIsNotApplied() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)
        viewModel.editInspectorDraft { $0.widthM = 0.3 }

        #expect(viewModel.selectedObject?.placement.sizeM == area.placement.sizeM)
    }

    private func makeAnnyeongContext() throws -> (LayoutEditorViewModel, LayoutObject) {
        let layout = PreviewLayouts.annyeong()
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session, onBack: {})
        let area = try #require(layout.objects.first { $0.kind == .closedArea })
        return (viewModel, area)
    }

    @Test("Editing wall length in the inspector updates wall length and stretches neighbours")
    func editingWallLengthInInspectorStretchesNeighbours() throws {
        let wall1 = LayoutObject(
            kind: .wall,
            label: "Wall 1",
            placement: Placement(center: SIMD2<Double>(5, 0), sizeM: SIMD2<Double>(10, 0.2))
        )
        let wall2 = LayoutObject(
            kind: .wall,
            label: "Wall 2",
            placement: Placement(center: SIMD2<Double>(10, 4), sizeM: SIMD2<Double>(8, 0.2), rotationRadians: .pi / 2)
        )
        let layout = Layout(name: "WallTest", sizeM: SIMD2<Double>(20, 20), objects: [wall1, wall2])
        let session = ProjectSession()
        let project = session.createProject(named: "WallProject")
        session.setDraft(
            ProjectDraft(name: "WallProject", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session, onBack: {})
        viewModel.selectObject(wall1.id)
        #expect(viewModel.inspectorDraft?.widthM == 10.0)

        viewModel.editInspectorDraft { $0.widthM = 15.0 }

        let savedWall1 = try #require(viewModel.activeLayout?.objects.first { $0.id == wall1.id })
        #expect(abs(savedWall1.placement.sizeM.x - 15.0) < 0.05)

        let active = try #require(viewModel.activeLayout)
        let graph = WallGraph(layout: active)
        let ep1 = try #require(graph.endpoints(for: wall1.id))
        let ep2 = try #require(graph.endpoints(for: wall2.id))
        #expect(simd_distance(ep1.end, SIMD2<Double>(15, 0)) < 0.05)
        #expect(simd_distance(ep2.start, SIMD2<Double>(15, 0)) < 0.05)
    }
}

@Suite("Live attractiveness and open/closed booth sides")
@MainActor
struct AttractivenessAndOpenSidesTests {
    @Test("Dragging the attractiveness slider continuously emits clamped integer steps")
    func sliderDragEmitsClampedIntegerSteps() throws {
        var current = 1.0
        let binding = Binding(get: { current }, set: { current = $0 })
        let slider = try #require(ViewInspectorHelper.findSlider(in: AttractivenessField(value: binding).body))

        #expect(slider.discreteValueCount == 0)

        let dragSamples: [(raw: Double, expected: Double)] = [
            (0.2, 1.0), (1.0, 1.0), (1.4, 1.0), (1.6, 2.0), (2.49, 2.0),
            (2.51, 3.0), (2.7, 3.0), (3.2, 3.0), (4.4, 4.0), (4.6, 5.0), (6.5, 5.0)
        ]
        let lower = AttractivenessField.range.lowerBound
        let span = AttractivenessField.range.upperBound - lower
        for sample in dragSamples {
            slider.binding.wrappedValue = (sample.raw - lower) / span
            #expect(current == sample.expected)
            #expect(AttractivenessField.isValid(current))
        }
    }

    @Test("Sequential attractiveness edits apply immediately and coalesce into one undo step")
    func sequentialAttractivenessUpdatesCoalesce() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)

        for step in [2.0, 3.0, 4.0, 5.0] {
            context.viewModel.editInspectorDraft { $0.attractiveness = step }
            #expect(context.viewModel.isInspectorDraftValid)
            let updated = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
            #expect(updated.attractiveness == step)
        }

        context.viewModel.editInspectorDraft { $0.attractiveness = -1 }
        #expect(!context.viewModel.isInspectorDraftValid)
        context.viewModel.editInspectorDraft { $0.attractiveness = 2.5 }
        #expect(!context.viewModel.isInspectorDraftValid)
        let retained = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(retained.attractiveness == 5.0)

        context.viewModel.undo()
        let restored = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(restored.attractiveness == 1.0)
        #expect(!context.viewModel.canUndo)
    }

    @Test("Selected booth in heat mode shows live attractiveness colour and distinct selection outline")
    func selectedBoothShowsAttractivenessHeatColor() throws {
        let lowSelected = try PixelBuffer.renderBooth(attractiveness: 1, isSelected: true, label: "")
        let highSelected = try PixelBuffer.renderBooth(attractiveness: 5, isSelected: true, label: "")
        let lowUnselected = try PixelBuffer.renderBooth(attractiveness: 1, isSelected: false, label: "")

        let lowCenter = lowSelected.pixel(col: 100, row: 100)
        let highCenter = highSelected.pixel(col: 100, row: 100)
        let selectionFill = RGBA(color: Palette.canvasSelection)

        #expect(lowCenter.isClose(to: lowUnselected.pixel(col: 100, row: 100)))
        #expect(!lowCenter.isClose(to: selectionFill))
        #expect(highCenter.isClose(to: RGBA(color: AttractivenessScale.color(for: 5))))
        #expect(!highCenter.isClose(to: selectionFill))
        let selectedEdge = lowSelected.pixel(col: 100, row: 59)
        let unselectedEdge = lowUnselected.pixel(col: 100, row: 59)
        #expect(!selectedEdge.isClose(to: unselectedEdge, tolerance: 30))
    }

    @Test("Selected booth in heat mode uses dark label on light steps and light label on dark steps")
    func selectedBoothLabelContrastFollowsHeatStep() throws {
        let lightBuffer = try PixelBuffer.renderBooth(attractiveness: 1, isSelected: true, label: "B8")
        let darkBuffer = try PixelBuffer.renderBooth(attractiveness: 5, isSelected: true, label: "B8")
        let labelRect = CGRect(x: 80, y: 85, width: 40, height: 30)

        #expect(lightBuffer.luminanceRange(in: labelRect).min < 0.45)
        #expect(darkBuffer.luminanceRange(in: labelRect).max > 0.70)
    }

    @Test("Blocked open sides draw no strip while closed sides keep their strip")
    func blockedOpenSideDrawsNoStrip() throws {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(4, 4)),
            openSides: [.top, .right]
        )
        let transform = CanvasTransform(scale: 20, offset: .zero)
        let view = Canvas { context, _ in
            BoothRenderer.drawOpenSideStrips(of: booth, blockedSides: [.top], in: &context, transform: transform)
        }
        .frame(width: 200, height: 200)

        let buffer = try PixelBuffer.render(view)
        #expect(buffer.pixel(col: 100, row: 62).alpha == 0)
        #expect(buffer.pixel(col: 138, row: 100).alpha == 0)
        #expect(buffer.pixel(col: 100, row: 138).isClose(to: RGBA(color: Palette.canvasOpenSide)))
    }

    @Test("OpenSidesControl uses destructive red for closed edges and updated caption")
    func openSidesControlUsesRedForClosedSides() throws {
        let control = OpenSidesControl(sides: .constant([]))
        let buffer = try PixelBuffer.render(control.frame(width: 290, height: 220).background(Palette.surface))

        #expect(buffer.count(matching: RGBA(color: Palette.destructive)) > 100)
        #expect(buffer.count(matching: RGBA(color: Palette.highlight)) == 0)

        let texts = ViewInspectorHelper.textDescriptions(in: control.body)
        #expect(texts.contains { $0.contains("Red = closed · click an edge to toggle") })
        #expect(!texts.contains { $0.contains("Orange = closed") })
    }
}

private struct RGBA: Equatable {
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

    var luminance: Double {
        (0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)) / 255.0
    }

    func isClose(to other: RGBA, tolerance: Int = 10) -> Bool {
        abs(Int(red) - Int(other.red)) <= tolerance
            && abs(Int(green) - Int(other.green)) <= tolerance
            && abs(Int(blue) - Int(other.blue)) <= tolerance
            && abs(Int(alpha) - Int(other.alpha)) <= tolerance
    }
}

@MainActor
private struct PixelBuffer {
    let bytes: [UInt8]
    let width: Int
    let height: Int

    static func render<V: View>(_ view: V) throws -> PixelBuffer {
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
        return PixelBuffer(bytes: bytes, width: image.width, height: image.height)
    }

    static func renderBooth(attractiveness: Double, isSelected: Bool, label: String) throws -> PixelBuffer {
        let booth = LayoutObject(
            kind: .booth,
            label: label,
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(4, 4)),
            openSides: .all,
            attractiveness: attractiveness
        )
        let state = BoothDrawState(
            booth: booth,
            displayLabel: label,
            isSelected: isSelected,
            isHovered: false,
            isGroupMember: false,
            isHoveredGroupMember: false,
            hasObjectWarning: false,
            blockedSides: [],
            categoryColor: nil,
            attractiveness: .heat
        )
        let transform = CanvasTransform(scale: 20, offset: .zero)
        let view = Canvas { context, _ in
            BoothRenderer.draw(state, in: &context, transform: transform)
        }
        .frame(width: 200, height: 200)
        return try render(view)
    }

    func pixel(col: Int, row: Int) -> RGBA {
        let offset = (row * width + col) * 4
        return RGBA(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: bytes[offset + 3])
    }

    func luminanceRange(in rect: CGRect) -> (min: Double, max: Double) {
        var lowest = 1.0
        var highest = 0.0
        for row in Int(rect.minY)..<Int(rect.maxY) {
            for col in Int(rect.minX)..<Int(rect.maxX) {
                let value = pixel(col: col, row: row).luminance
                lowest = min(lowest, value)
                highest = max(highest, value)
            }
        }
        return (lowest, highest)
    }

    func count(matching target: RGBA) -> Int {
        var matches = 0
        for index in stride(from: 0, to: width * height * 4, by: 4) {
            let sample = RGBA(
                red: bytes[index],
                green: bytes[index + 1],
                blue: bytes[index + 2],
                alpha: bytes[index + 3]
            )
            if sample.isClose(to: target) { matches += 1 }
        }
        return matches
    }
}

private enum ViewInspectorHelper {
    static func findSlider(in root: Any) -> (binding: Binding<Double>, discreteValueCount: Int)? {
        if let slider = root as? Slider<EmptyView, EmptyView> {
            var valueBinding: Binding<Double>?
            var discreteCount = 0
            for child in Mirror(reflecting: slider).children {
                if child.label == "_value", let binding = child.value as? Binding<Double> {
                    valueBinding = binding
                } else if child.label == "discreteValueCount", let count = child.value as? Int {
                    discreteCount = count
                }
            }
            if let valueBinding { return (valueBinding, discreteCount) }
        }
        for child in Mirror(reflecting: root).children {
            if let match = findSlider(in: child.value) { return match }
        }
        return nil
    }

    static func textDescriptions(in root: Any) -> [String] {
        var results: [String] = []
        collectTexts(in: root, into: &results)
        return results
    }

    private static func collectTexts(in root: Any, into results: inout [String]) {
        if let text = root as? Text {
            results.append(String(describing: text))
            return
        }
        for child in Mirror(reflecting: root).children {
            collectTexts(in: child.value, into: &results)
        }
    }
}
