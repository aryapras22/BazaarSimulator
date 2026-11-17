import SwiftUI

/// A saved run inside a project folder. Double-clicking or choosing Rename turns the name into a text field.
struct SavedAnalysisRow: View {
    let name: String
    let detail: String
    let isSelected: Bool
    let isRenaming: Bool
    var isLoading = false
    let onCommitRename: (String) -> Void

    @State private var draftName = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(Palette.accentIcon)
            }

            if isRenaming {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(Typography.body)
                    .foregroundColor(Palette.textPrimary)
                    .focused($isFieldFocused)
                    .onSubmit { onCommitRename(draftName) }
                    .onExitCommand { onCommitRename(name) }
                    .onAppear {
                        draftName = name
                        isFieldFocused = true
                    }
            } else {
                Text(name)
                    .font(Typography.body)
                    .foregroundColor(isLoading ? Palette.textSecondary : Palette.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Text(detail)
                .font(Typography.caption)
                .foregroundColor(Palette.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .background(isSelected ? Palette.selection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(isSelected ? Palette.selectionBorder : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        SavedAnalysisRow(name: "Run 1", detail: "10:42", isSelected: true, isRenaming: false, onCommitRename: { _ in })
        SavedAnalysisRow(name: "Run 2", detail: "11:05", isSelected: false, isRenaming: true, onCommitRename: { _ in })
    }
    .padding()
    .background(Palette.sidebarBase)
    .preferredColorScheme(.dark)
}
