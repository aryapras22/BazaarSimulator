import SwiftUI

struct SegmentedTabs<Tab: Hashable>: View {
    @Binding var selection: Tab
    let tabs: [Tab]
    let title: (Tab) -> String

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selection == tab
                Button {
                    selection = tab
                } label: {
                    Text(title(tab))
                        .font(Typography.segment)
                        .foregroundStyle(textColor(isSelected: isSelected))
                        .lineLimit(1)
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.s)
                                .fill(isSelected ? Palette.segmentedSelected : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.m)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private func textColor(isSelected: Bool) -> Color {
        guard isEnabled else { return Palette.textDisabled }
        return isSelected ? Palette.textPrimary : Palette.textSecondary
    }
}

#Preview("Normal") {
    @Previewable @State var selected = "Floor Plan"
    SegmentedTabs(
        selection: $selected,
        tabs: ["Floor Plan", "Flow"],
        title: { $0 }
    )
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    @Previewable @State var selected = "Crowd Density Overview"
    SegmentedTabs(
        selection: $selected,
        tabs: ["Crowd Density Overview", "Visitor Flow Rate Analysis"],
        title: { $0 }
    )
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    @Previewable @State var selected = ""
    SegmentedTabs(
        selection: $selected,
        tabs: ["", "Flow"],
        title: { $0 }
    )
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    @Previewable @State var selected = "Flow"
    SegmentedTabs(
        selection: $selected,
        tabs: ["Floor Plan", "Flow"],
        title: { $0 }
    )
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    @Previewable @State var selected = "Floor Plan"
    SegmentedTabs(
        selection: $selected,
        tabs: ["Floor Plan", "Flow"],
        title: { $0 }
    )
    .disabled(true)
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
