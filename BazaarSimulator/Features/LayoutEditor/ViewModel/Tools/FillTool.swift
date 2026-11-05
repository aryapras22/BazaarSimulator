import Foundation
import simd

@MainActor
final class FillTool: EditorToolHandling {
    let sizeM: SIMD2<Double>
    let aisleWidthM: Double
    var tool: EditorTool { .fill(sizeM: sizeM, aisleWidthM: aisleWidthM) }

    private(set) var startWorld: SIMD2<Double>?
    private(set) var currentWorld: SIMD2<Double>?

    init(sizeM: SIMD2<Double> = SIMD2(2.5, 2.5), aisleWidthM: Double = 2.0) {
        self.sizeM = sizeM
        self.aisleWidthM = aisleWidthM
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        let isFree = event.modifiers.contains(.option)
        let snapResult = Snapper.snap(
            point: event.worldPoint,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: isFree
        )
        startWorld = snapResult.point
        currentWorld = snapResult.point
        context.setPreview(CanvasDragState(guides: snapResult.guides))
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        let isFree = event.modifiers.contains(.option)
        let snapResult = Snapper.snap(
            point: event.worldPoint,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: isFree
        )
        currentWorld = snapResult.point
        guard let start = startWorld else {
            context.setPreview(CanvasDragState(guides: snapResult.guides))
            return
        }

        let plan = BoothRowPlanner.planFill(
            from: start,
            to: snapResult.point,
            boothSize: sizeM,
            aisleWidthM: aisleWidthM,
            in: context.layout
        )
        let previewInserts = plan.booths.map {
            LayoutObject(id: $0.id, kind: .booth, label: "", placement: $0.placement, openSides: $0.openSides)
        }
        let warningIDs = Set(plan.booths.filter { !$0.isValid }.map(\.id))
        let chip = "\(plan.validCount) booths, \(plan.skippedCount) skipped"
        context.setPreview(CanvasDragState(
            previewInserts: previewInserts,
            previewWarningIDs: warningIDs,
            guides: snapResult.guides,
            wallLengthChipText: chip,
            wallLengthChipWorld: snapResult.point
        ))
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {
        defer {
            startWorld = nil
            currentWorld = nil
            context.clearPreview()
            context.switchTool(.select)
        }
        guard let start = startWorld, let current = currentWorld else { return }
        let plan = BoothRowPlanner.planFill(
            from: start,
            to: current,
            boothSize: sizeM,
            aisleWidthM: aisleWidthM,
            in: context.layout
        )
        let validBooths = plan.booths.filter(\.isValid)
        guard !validBooths.isEmpty else { return }

        let labels = nextLabels(count: validBooths.count, in: context.layout)
        var edits: [LayoutEdit] = []
        var firstID: UUID?
        for (index, planned) in validBooths.enumerated() {
            let booth = LayoutObject(
                kind: .booth,
                label: labels[index],
                placement: planned.placement,
                openSides: planned.openSides
            )
            if firstID == nil { firstID = booth.id }
            edits.append(.insert(booth, index: context.layout.objects.count + index))
        }

        context.applyEdit(.batch(edits))
        if let firstID {
            context.selectObject(firstID)
        }
    }

    func handleDoubleClick(_ event: CanvasPointerEvent, context: ToolContext) {}

    func handleKey(_ key: CanvasKey, context: ToolContext) -> Bool {
        switch key {
        case .escape:
            cancel(context: context)
            return true
        default:
            return false
        }
    }

    func cancel(context: ToolContext) {
        startWorld = nil
        currentWorld = nil
        context.clearPreview()
        context.switchTool(.select)
    }

    private func nextLabels(count: Int, in layout: Layout) -> [String] {
        let prefix = "N"
        let highest = layout.objects
            .filter { $0.kind == .booth && $0.label.hasPrefix(prefix) }
            .compactMap { Int($0.label.dropFirst(prefix.count)) }
            .max() ?? 0
        return (1...count).map { "\(prefix)\(highest + $0)" }
    }
}
