import SwiftUI

struct UnsavedChangesDialog: ViewModifier {
    let isPresented: Binding<Bool>
    let canSave: Bool
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "You have unsaved changes in the inspector.",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            if canSave {
                Button("Save Changes") {
                    onSave()
                }
            }
            Button("Discard Changes", role: .destructive) {
                onDiscard()
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
        } message: {
            Text("Save or discard your edits before continuing.")
        }
    }
}

extension View {
    func unsavedChangesDialog(
        isPresented: Binding<Bool>,
        canSave: Bool,
        onSave: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(
            UnsavedChangesDialog(
                isPresented: isPresented,
                canSave: canSave,
                onSave: onSave,
                onDiscard: onDiscard,
                onCancel: onCancel
            )
        )
    }
}
