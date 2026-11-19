import SwiftUI

struct AttractivenessLegend: View {
    @Binding var isOn: Bool

    private var glass: Glass {
        isOn ? .regular.tint(Palette.accent.opacity(0.5)).interactive() : .regular.interactive()
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: Spacing.s) {
                Text("Attractiveness")
                    .font(Typography.caption)
                if isOn {
                    Text("\(Int(AttractivenessField.range.lowerBound.rounded()))")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Capsule()
                        .fill(AttractivenessScale.gradient)
                        .frame(width: 72, height: 8)
                    Text("\(Int(AttractivenessField.range.upperBound.rounded()))")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .glassEffect(glass, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Hide attractiveness colours" : "Colour booths by attractiveness")
        .accessibilityLabel("Show attractiveness on booths")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    GlassEffectContainer(spacing: Spacing.m) {
        VStack(alignment: .trailing, spacing: Spacing.m) {
            AttractivenessLegend(isOn: .constant(false))
            AttractivenessLegend(isOn: .constant(true))
        }
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
