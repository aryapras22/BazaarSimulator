import Foundation

struct LayoutEditHistory: Sendable, Equatable {
    static let maxEntries = 200

    private struct Entry: Sendable, Equatable {
        var edit: LayoutEdit
        var coalesceKey: String?
        var isSealed: Bool
    }

    private var entries: [Entry] = []
    private(set) var redoStack: [LayoutEdit] = []

    var undoStack: [LayoutEdit] {
        entries.map(\.edit)
    }

    var canUndo: Bool { !entries.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func record(_ edit: LayoutEdit, coalesceKey: String? = nil) {
        if let coalesceKey,
           let last = entries.last,
           !last.isSealed,
           last.coalesceKey == coalesceKey,
           case let .replace(before: initial, after: _) = last.edit,
           case let .replace(before: _, after: latest) = edit,
           initial.id == latest.id {
            if initial == latest {
                entries.removeLast()
            } else {
                entries[entries.count - 1].edit = .replace(before: initial, after: latest)
            }
            redoStack.removeAll()
            return
        }

        entries.append(Entry(edit: edit, coalesceKey: coalesceKey, isSealed: false))
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        redoStack.removeAll()
    }

    mutating func seal() {
        guard !entries.isEmpty else { return }
        entries[entries.count - 1].isSealed = true
    }

    mutating func undo() -> LayoutEdit? {
        guard let last = entries.popLast() else { return nil }
        seal()
        redoStack.append(last.edit)
        return LayoutEditing.inverse(of: last.edit)
    }

    mutating func redo() -> LayoutEdit? {
        seal()
        guard let next = redoStack.popLast() else { return nil }
        entries.append(Entry(edit: next, coalesceKey: nil, isSealed: true))
        return next
    }

    mutating func clear() {
        entries.removeAll()
        redoStack.removeAll()
    }
}
