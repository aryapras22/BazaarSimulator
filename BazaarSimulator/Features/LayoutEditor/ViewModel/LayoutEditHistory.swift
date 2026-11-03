import Foundation

struct LayoutEditHistory: Sendable, Equatable {
    static let maxEntries = 200

    private(set) var undoStack: [LayoutEdit] = []
    private(set) var redoStack: [LayoutEdit] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func record(_ edit: LayoutEdit) {
        undoStack.append(edit)
        if undoStack.count > Self.maxEntries {
            undoStack.removeFirst(undoStack.count - Self.maxEntries)
        }
        redoStack.removeAll()
    }

    mutating func undo() -> LayoutEdit? {
        guard let last = undoStack.popLast() else { return nil }
        redoStack.append(last)
        return LayoutEditing.inverse(of: last)
    }

    mutating func redo() -> LayoutEdit? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(next)
        return next
    }

    mutating func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
