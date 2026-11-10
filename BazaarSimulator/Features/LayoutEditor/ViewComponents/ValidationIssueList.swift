import SwiftUI

struct ValidationIssueList: View {
    let issues: [LayoutIssue]
    let onFocus: (LayoutIssue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(sortedIssues) { issue in
                row(for: issue)
            }
        }
    }

    private var sortedIssues: [LayoutIssue] {
        issues.filter { $0.severity == .error } + issues.filter { $0.severity == .warning }
    }

    private func row(for issue: LayoutIssue) -> some View {
        let isError = issue.severity == .error
        let tint = isError ? Palette.destructive : Palette.highlight
        return Button {
            onFocus(issue)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: isError ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(Typography.caption)
                    .foregroundStyle(tint)
                Text(issue.message)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(issue.objectIDs.isEmpty)
        .help(issue.objectIDs.isEmpty ? issue.message : "Select and show on the canvas")
        .accessibilityLabel(issue.message)
    }
}
