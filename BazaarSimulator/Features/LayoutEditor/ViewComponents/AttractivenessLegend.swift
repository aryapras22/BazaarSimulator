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
                popularityIcon
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
        .help(isOn ? "Hide popularity colours" : "Colour booths by popularity")
        .accessibilityLabel("Show popularity on booths")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // SF Symbols has no person-with-star glyph, so the star is stacked above a person.
    private var popularityIcon: some View {
        VStack(spacing: 0) {
            Image(systemName: "star.fill")
                .font(.system(size: 7, weight: .bold))
            Image(systemName: "person.fill")
                .font(.system(size: 13, weight: .medium))
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
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
