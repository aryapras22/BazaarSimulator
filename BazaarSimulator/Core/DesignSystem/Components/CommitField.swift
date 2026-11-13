import SwiftUI

/// A text field that keeps its own draft while typing and commits on Return or when it loses focus.
/// `onCommit` returns the text to show afterwards, so rejected input snaps back to the last good value.
struct CommitField: View {
    let value: String
    var suffix: String?
    var alignment: TextAlignment = .leading
    let onCommit: (String) -> String

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            TextField("", text: $text)
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
        .onAppear { text = value }
        .onChange(of: value) { _, newValue in text = newValue }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
    }

    private func commit() {
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
