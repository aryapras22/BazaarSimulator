import SwiftUI

struct ProjectRow: View {
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "folder")
                .foregroundColor(Palette.textSecondary)

            Text(name)
                .font(Typography.body)
                .foregroundColor(Palette.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(isSelected ? Palette.selection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(isSelected ? Palette.selectionBorder : Color.clear, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        ProjectRow(name: "Bazaar 1", isSelected: true)
        ProjectRow(name: "Bazaar 2", isSelected: false)
    }
    .padding()
    .background(Palette.sidebarBase)
    .preferredColorScheme(.dark)
}
