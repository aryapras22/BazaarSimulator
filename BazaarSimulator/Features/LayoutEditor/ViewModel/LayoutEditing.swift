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
        }
        return updated
    }

    static func inverse(of edit: LayoutEdit) -> LayoutEdit {
        switch edit {
        case let .replace(before, after):
            return .replace(before: after, after: before)
        case let .insert(object, index):
            return .delete(object, index: index)
        case let .delete(object, index):
            return .insert(object, index: index)
        }
    }
}
