import SwiftUI

struct EditorCommandActions {
    var canUndo: Bool
    var canRedo: Bool
    var hasSelection: Bool
    var canDuplicate: Bool
    var canRotate: Bool
    var undo: () -> Void
    var redo: () -> Void
    var deleteSelected: () -> Void
    var duplicateSelected: () -> Void
    var rotateSelected: () -> Void
    var zoomIn: () -> Void
    var zoomOut: () -> Void
    var fitToView: () -> Void
    var selectStructureLayer: () -> Void
    var selectBoothsLayer: () -> Void
}

private struct EditorCommandActionsKey: FocusedValueKey {
    typealias Value = EditorCommandActions
}

extension FocusedValues {
    var editorCommandActions: EditorCommandActions? {
        get { self[EditorCommandActionsKey.self] }
        set { self[EditorCommandActionsKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.editorCommandActions) private var actions
    @AppStorage(DevMode.defaultsKey) private var isDevModeOn = false

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                actions?.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!(actions?.canUndo ?? false))

            Button("Redo") {
                actions?.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!(actions?.canRedo ?? false))
        }

        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Duplicate") {
                actions?.duplicateSelected()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(!(actions?.canDuplicate ?? false))

            Button("Rotate 90°") {
                actions?.rotateSelected()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!(actions?.canRotate ?? false))

            Button("Delete") {
                actions?.deleteSelected()
            }
            .disabled(!(actions?.hasSelection ?? false))
        }

        CommandGroup(after: .toolbar) {
            Button("Zoom In") {
                actions?.zoomIn()
            }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(actions == nil)

            Button("Zoom Out") {
                actions?.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(actions == nil)

            Button("Zoom to Fit") {
                actions?.fitToView()
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(actions == nil)
        }

        CommandMenu("Layer") {
            Button("Structure") {
                actions?.selectStructureLayer()
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(actions == nil)

            Button("Booths") {
                actions?.selectBoothsLayer()
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(actions == nil)
        }

        CommandMenu("Developer") {
            Toggle("Dev Mode", isOn: $isDevModeOn)
        }
    }
}
