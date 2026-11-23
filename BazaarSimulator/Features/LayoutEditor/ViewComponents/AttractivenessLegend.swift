import SwiftUI

struct AttractivenessLegend: View {
    var body: some View {
        HStack(spacing: Spacing.s) {
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
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Popularity scale 1 to 5")
    }
}

#Preview {
    GlassEffectContainer(spacing: Spacing.m) {
        AttractivenessLegend()
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
