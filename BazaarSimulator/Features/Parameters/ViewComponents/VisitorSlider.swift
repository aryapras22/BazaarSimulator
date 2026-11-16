import SwiftUI

/// What a visitor type looks like in the slider. The share itself comes from `VisitorMix`.
struct VisitorSliderItem: Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String
    let color: Color
    var labelColor: Color = Palette.tipText
}

extension VisitorSliderItem {
    private static let styles: [(color: Color, label: Color)] = [
        (Palette.visitorSeries1, Palette.textPrimary),
        (Palette.visitorSeries2, Palette.textPrimary),
        (Palette.visitorSeries3, Palette.textPrimary),
        (Palette.visitorSeries4, Palette.textPrimary)
    ]

    /// Colors follow the order of the types and repeat if there are more than four.
    static func items(for types: [VisitorType]) -> [VisitorSliderItem] {
        types.enumerated().map { index, type in
            let style = styles[index % styles.count]
            return VisitorSliderItem(
                id: type.id, name: type.name, summary: type.summary,
                color: style.color, labelColor: style.label
            )
        }
    }
}

/// A composition bar on top and one slider per visitor type below it.
/// Moving a slider rescales the unlocked others, so the shares always total 100%.
struct VisitorSlider: View {
    let items: [VisitorSliderItem]
    let mix: VisitorMix
    let onChange: (String, Int) -> Void
    let onToggleLock: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            CompositionBar(segments: segments)

            HStack {
                Text("Total")
                Spacer()
                Text("\(mix.shares.reduce(0) { $0 + $1.percent })%")
            }
            .font(Typography.caption)
            .foregroundColor(Palette.textSecondary)

            Divider().background(Palette.surfaceBorder)

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let share = mix.share(for: item.id)
                VisitorTypeRow(
                    name: item.name,
                    summary: item.summary,
                    color: item.color,
                    percent: share?.percent ?? 0,
                    isLocked: share?.isLocked ?? false,
                    isEditable: mix.canEdit(item.id),
                    onChange: { onChange(item.id, $0) },
                    onToggleLock: { onToggleLock(item.id) }
                )
                .padding(.vertical, Spacing.xs)

                if index < items.count - 1 {
                    Divider().background(Palette.surfaceBorder)
                }
            }

            Text("Lock a type to keep it fixed.")
                .font(Typography.caption)
                .foregroundColor(Palette.textSecondary)
                .padding(.top, Spacing.s)
        }
    }

    private var segments: [CompositionBarSegment] {
        items.map { item in
            let percent = mix.share(for: item.id)?.percent ?? 0
            return CompositionBarSegment(
                id: item.id, value: Double(percent), color: item.color,
                label: "\(percent)%", labelColor: item.labelColor
            )
        }
    }
}

private struct VisitorSliderPreview: View {
    private let catalog = PresetCatalog.bundled()
    @State private var mix = VisitorMix(shares: [
        .init(id: "socializer", percent: 21), .init(id: "family", percent: 46),
        .init(id: "stroller", percent: 30), .init(id: "buyer", percent: 3)
    ])

    var body: some View {
        VisitorSlider(
            items: VisitorSliderItem.items(for: catalog.visitorTypes),
            mix: mix,
            onChange: { mix.setPercent($1, for: $0) },
            onToggleLock: { mix.toggleLock(for: $0) }
        )
        .padding()
        .frame(width: 520)
        .background(Palette.background)
    }
}

#Preview("Normal") {
    VisitorSliderPreview()
        .preferredColorScheme(.dark)
}
