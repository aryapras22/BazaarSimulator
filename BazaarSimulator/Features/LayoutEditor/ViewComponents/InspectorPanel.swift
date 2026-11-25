import SwiftUI

enum InspectorPanelMetrics {
    /// Fixed width of the floating inspector, in points.
    static let width: CGFloat = 288
    /// The gap between the inspector and the edges of the window.
    static let margin: CGFloat = 12
}

/// The rounded card the inspector lives in. It floats over the right of the canvas.
struct InspectorSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        content()
            .frame(width: InspectorPanelMetrics.width)
            .frame(maxHeight: .infinity)
            .background {
                shape
                    .fill(Color(hex: 0x2C3D5A))
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.07), Color.clear], startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 70)
                        .clipShape(shape)
                    }
                    .overlay { shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            }
    }
}

/// The inspector for what is selected: its name with a pencil to change it, its fields, and at the bottom the notes
/// about it, such as validation messages and tips, and the button that finishes editing.
struct InspectorPanel<Content: View, Footer: View>: View {
    let title: String
    /// The text the pencil edits. Nil leaves the name as it is.
    var editableName: String?
    var onRename: (String) -> Void = { _ in }
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        InspectorSurface {
            VStack(alignment: .leading, spacing: Spacing.l) {
                RenameableTitle(title: title, editableName: editableName, onRename: onRename)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.l) {
                        content()
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: Spacing.s) {
                    footer()
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.l + 2)
            .padding(.bottom, Spacing.m)
        }
    }
}

/// A name that turns into a text field when its pencil is pressed. Return keeps the new name, Escape drops it.
struct RenameableTitle: View {
    let title: String
    var editableName: String?
    let onRename: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            if isEditing {
                TextField("Name", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onExitCommand { isEditing = false }
                    .padding(.horizontal, Spacing.s)
                    .frame(height: 28)
                    .background(Color(hex: 0x1F2E48), in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                    .onChange(of: isFocused) { _, focused in
                        if !focused && isEditing { commit() }
                    }
            } else {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)

                if let editableName {
                    Button {
                        draft = editableName
                        isEditing = true
                        isFocused = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Palette.textSecondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Rename")
                    .accessibilityLabel("Rename \(title)")
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 28)
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != editableName else { return }
        onRename(trimmed)
    }
}

/// The notes at the bottom of the inspector: what is wrong with the selection, in red for errors and orange for
/// warnings.
struct InspectorNotes: View {
    let messages: [(text: String, isError: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Image(systemName: message.isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .font(Typography.caption)
                        .foregroundColor(message.isError ? Palette.destructive : Palette.highlight)
                    Text(message.text)
                        .font(Typography.caption)
                        .foregroundColor(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// A suggestion, in the light blue card of the design, with a button to take it up.
struct InspectorTip: View {
    let message: String
    var actionTitle: String?
    var onAction: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Tip: \(message)")
                .font(.system(size: 11))
                .foregroundColor(Palette.tipText)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Palette.tipText)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, 4)
                        .background(Palette.tipButton, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.tipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Finishes editing the selection. It is dimmed while what was entered cannot be used.
struct SaveChangesButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Save Changes")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.highlight)
        .disabled(!isEnabled)
        .keyboardShortcut(.return, modifiers: .command)
        .help("Keep the changes and close this panel (⌘↩)")
    }
}

/// Removes the selection. It has the shape of Save Changes, in the red of a destructive action.
struct DeleteSelectionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DeleteSelectionButtonStyle())
        .help("\(title) (⌫)")
    }
}

private struct DeleteSelectionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(Palette.destructive.opacity(configuration.isPressed ? 0.8 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
    }
}

#Preview {
    InspectorPanel(title: "Booth B-7", editableName: "B-7") {
        Text("Panel content")
            .foregroundStyle(Palette.textSecondary)
    } footer: {
        InspectorTip(message: "Door NE is already “Exit”. Make NW “Entrance”?", actionTitle: "Use “Entrance”")
        DeleteSelectionButton(title: "Delete booth", action: {})
        SaveChangesButton(isEnabled: true, action: {})
    }
    .frame(height: 500)
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
