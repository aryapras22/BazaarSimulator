import Foundation

enum LayoutEditing {
    static func apply(_ edit: LayoutEdit, to layout: Layout) -> Layout {
        var updated = layout
        switch edit {
        case let .replace(before, after):
            if let index = updated.objects.firstIndex(where: { $0.id == before.id }) {
                updated.objects[index] = after
            }
        case let .insert(object, index):
            let clamped = min(max(index, 0), updated.objects.count)
            updated.objects.insert(object, at: clamped)
        case let .delete(object, _):
            updated.objects.removeAll { $0.id == object.id }
        case let .setOutline(_, after):
            applyOutline(after, to: &updated)
        case let .batch(edits):
            updated = edits.reduce(layout) { apply($1, to: $0) }
        }
        return updated
    }

    private static func applyOutline(_ outline: LayoutOutline, to layout: inout Layout) {
        layout.hall = outline.hall
        layout.sizeM = outline.sizeM
        if let lobby = outline.lobby { layout.lobby = lobby }
        if let markers = outline.markers { layout.markers = markers }
        if let zones = outline.zones { layout.zones = zones }
    }

    static func inverse(of edit: LayoutEdit) -> LayoutEdit {
        switch edit {
        case let .replace(before, after):
            return .replace(before: after, after: before)
        case let .insert(object, index):
            return .delete(object, index: index)
        case let .delete(object, index):
            return .insert(object, index: index)
        case let .setOutline(before, after):
            return .setOutline(before: after, after: before)
        case let .batch(edits):
            return .batch(edits.reversed().map(inverse(of:)))
        }
    }
}
