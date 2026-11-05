import SwiftUI

/// A pop-up menu styled as a field. Takes plain values, so it works for any option type.
struct DropdownField<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(title(option)) { selection = option }
            }
        } label: {
            HStack(spacing: Spacing.s) {
                Text(title(selection))
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: Spacing.s)
                Image(systemName: "chevron.up.chevron.down")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(RoundedRectangle(cornerRadius: Radius.s).fill(Palette.fieldOnSurface))
            .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(Palette.fieldOnSurfaceBorder, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

#Preview("Normal") {
    @Previewable @State var selection = "Family & Kids"
    DropdownField(options: ["Family & Kids", "Food Festival"], selection: $selection) { $0 }
        .frame(width: 230)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}
