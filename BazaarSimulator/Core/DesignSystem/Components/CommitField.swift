import SwiftUI

/// Collects active `CommitField` instances in a form so an explicit Apply button can commit any
/// currently focused field synchronously before saving.
@MainActor
final class FormCommitScope {
    private var committers: [UUID: () -> Void] = [:]

    func register(id: UUID, commit: @escaping () -> Void) {
        committers[id] = commit
    }

    func unregister(id: UUID) {
        committers.removeValue(forKey: id)
    }

    func commitAll() {
        for commit in committers.values {
            commit()
        }
    }
}

private struct FormCommitScopeKey: EnvironmentKey {
    static let defaultValue: FormCommitScope? = nil
}

extension EnvironmentValues {
    var formCommitScope: FormCommitScope? {
        get { self[FormCommitScopeKey.self] }
        set { self[FormCommitScopeKey.self] = newValue }
    }
}

/// A text field that keeps its own draft while typing and commits on Return or when it loses focus.
/// `onCommit` returns the text to show afterwards, so rejected input snaps back to the last good value.
struct CommitField: View {
    let value: String
    var suffix: String?
    var alignment: TextAlignment = .leading
    let onCommit: (String) -> String

    @State private var text = ""
    @State private var isDirty = false
    @State private var fieldID = UUID()
    @FocusState private var isFocused: Bool
    @Environment(\.formCommitScope) private var commitScope

    var body: some View {
        HStack(spacing: Spacing.s) {
            TextField(
                "",
                text: Binding(
                    get: { text },
                    set: { newText in
                        text = newText
                        isDirty = true
                    }
                )
            )
            .textFieldStyle(.plain)
            .multilineTextAlignment(alignment)
            .focused($isFocused)
            .onSubmit(commit)
            if let suffix {
                Text(suffix)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }
        }
        .font(Typography.body)
        .foregroundStyle(Palette.textPrimary)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(RoundedRectangle(cornerRadius: Radius.s).fill(Palette.fieldOnSurface))
        .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(Palette.fieldOnSurfaceBorder, lineWidth: 1))
        .onAppear {
            text = value
            isDirty = false
            registerCommitter()
        }
        .onChange(of: value) { _, newValue in
            text = newValue
            isDirty = false
            registerCommitter()
        }
        .onDisappear {
            commitScope?.unregister(id: fieldID)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
    }

    private func registerCommitter() {
        commitScope?.register(id: fieldID) {
            guard isDirty else { return }
            commit()
        }
    }

    private func commit() {
        isDirty = false
        text = onCommit(text)
    }
}

#Preview("Normal") {
    CommitField(value: "5000", suffix: "people") { $0 }
        .frame(width: 230)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Centered") {
    CommitField(value: "46", alignment: .center) { $0 }
        .frame(width: 52)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}
