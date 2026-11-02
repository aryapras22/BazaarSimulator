import SwiftUI

struct SidebarSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Palette.textSecondary)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundColor(Palette.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Palette.field)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Palette.fieldBorder, lineWidth: 1)
        )
    }
}

#Preview {
    SidebarSearchField(text: .constant("Bazaar"))
        .padding()
        .background(Palette.sidebarBase)
        .preferredColorScheme(.dark)
}
