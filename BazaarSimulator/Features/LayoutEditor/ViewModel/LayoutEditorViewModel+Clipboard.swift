import Foundation
import simd

extension LayoutEditorViewModel {
    static let clipboardPasteStepM = SIMD2<Double>(1.0, 1.0)

    var canCopy: Bool {
        !copyableSelection.isEmpty
    }

    var canPaste: Bool {
        !clipboard.isEmpty && activeLayout != nil
    }

    func copySelected() {
        let selection = copyableSelection
        guard !selection.isEmpty else { return }
        clipboard = selection
        clipboardPasteCount = 0
    }

    func pasteClipboard() {
        guard let layout = activeLayout, !clipboard.isEmpty else { return }
        clipboardPasteCount += 1
        let offset = Self.clipboardPasteStepM * Double(clipboardPasteCount)

        var workingLayout = layout
        var edits: [LayoutEdit] = []
        var pastedIDs: Set<UUID> = []

        for source in clipboard {
            var copy = source
            copy.id = UUID()
            copy.label = pastedLabel(for: source, in: workingLayout)
            copy.placement.center += offset
            let insertIndex = workingLayout.objects.count
            workingLayout.objects.append(copy)
            edits.append(.insert(copy, index: insertIndex))
            pastedIDs.insert(copy.id)
        }

        withSingleRefresh {
            if let targetLayer = clipboard.first?.kind.layer {
                selectLayer(targetLayer)
            }
            commitEdit(.batch(edits))
            applyMemberSelection(pastedIDs, kind: .custom)
        }
    }

    private var copyableSelection: [LayoutObject] {
        if groupSelection != nil {
            return selectedGroupMembers.filter(\.kind.isMovable)
        }
        if let selected = selectedObject, selected.kind.isMovable {
            return [selected]
        }
        return []
    }

    private func pastedLabel(for source: LayoutObject, in layout: Layout) -> String {
        if source.kind == .booth {
            let prefix = BoothGrouping.namePrefix(of: source.label)
            return LayoutObjectNaming.nextPrefixedLabel(prefix: prefix, kind: .booth, in: layout)
        }
        let candidate = LayoutObjectNaming.nextLabel(for: source.kind, in: layout)
        guard source.kind != .closedArea,
              layout.objects.contains(where: { $0.label == candidate }) else {
            return candidate
        }
        return LayoutObjectNaming.nextPrefixedLabel(
            prefix: "\(source.kind.displayName) ",
            kind: source.kind,
            in: layout
        )
    }
}
