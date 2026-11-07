import SwiftUI

struct AttractivenessLegend: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: "thermometer.medium")
                    .font(Typography.caption)
                Text("Attractiveness")
                    .font(Typography.caption)
                if isOn {
                    Text("0")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Capsule()
                        .fill(AttractivenessScale.gradient)
                        .frame(width: 72, height: 8)
                    Text("10")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Capsule().fill(Palette.surface))
            .overlay(Capsule().stroke(isOn ? Palette.accentIcon : Palette.surfaceBorder, lineWidth: isOn ? 2 : 1))
        }
        .buttonStyle(.plain)
        .help(isOn ? "Hide attractiveness colours" : "Colour booths by attractiveness")
        .accessibilityLabel("Show attractiveness on booths")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: Spacing.m) {
        AttractivenessLegend(isOn: .constant(false))
        AttractivenessLegend(isOn: .constant(true))
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
