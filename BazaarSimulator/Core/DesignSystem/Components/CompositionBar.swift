import SwiftUI

struct CompositionBarSegment: Identifiable, Equatable {
    let id: String
    let value: Double
    let color: Color
    let label: String
    var labelColor: Color = Palette.tipText
}

/// One horizontal bar split into colored segments, sized by each segment's share of the total.
struct CompositionBar: View {
    let segments: [CompositionBarSegment]

    private let gap: CGFloat = 0
    private let minLabelWidth: CGFloat = 36

    var body: some View {
        GeometryReader { geometry in
            let total = segments.reduce(0) { $0 + max($1.value, 0) }
            let usable = max(0, geometry.size.width - gap * CGFloat(max(segments.count - 1, 0)))
            HStack(spacing: gap) {
                ForEach(segments) { segment in
                    let width = total > 0 ? usable * CGFloat(max(segment.value, 0) / total) : 0
                    Rectangle()
                        .fill(segment.color)
                        .overlay {
                            if width >= minLabelWidth {
                                Text(segment.label)
                                    .font(Typography.inspectorLabel)
                                    .foregroundColor(segment.labelColor)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: width)
                }
            }
            .cornerRadius(12)
            .animation(.easeOut(duration: 0.15), value: segments)
        }
        .frame(height: 32)
    }
}

#Preview("Normal") {
    CompositionBar(segments: [
        .init(id: "a", value: 40, color: Palette.visitorSeries1, label: "40%"),
        .init(id: "b", value: 30, color: Palette.visitorSeries2, label: "30%"),
        .init(id: "c", value: 20, color: Palette.visitorSeries3, label: "20%"),
        .init(id: "d", value: 10, color: Palette.visitorSeries4, label: "10%")
    ])
    .frame(width: 420)
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    CompositionBar(segments: [
        .init(id: "a", value: 100, color: Palette.visitorSeries1, label: "100%"),
        .init(id: "b", value: 0, color: Palette.visitorSeries2, label: "0%")
    ])
    .frame(width: 420)
    .padding()
    .preferredColorScheme(.dark)
}
