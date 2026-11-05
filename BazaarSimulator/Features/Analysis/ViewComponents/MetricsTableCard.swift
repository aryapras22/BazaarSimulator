import SwiftUI

struct MetricsTableCard: View {
    let content: AnalysisContent

    private enum Column {
        static let name = CardInset.horizontal
        static let minimum: CGFloat = 0.216
        static let average: CGFloat = 0.364
        static let maximum: CGFloat = 0.513
        static let meaning: CGFloat = 0.624
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let headerY = CardInset.top + CardTitle.height + 15
            let dividerY = headerY + 20
            let rowHeight = (height - dividerY - 3) / CGFloat(max(content.rows.count, 1))

            ZStack(alignment: .topLeading) {
                CardHeading(title: content.tableTitle, measure: content.measure)
                    .frame(width: width - CardInset.horizontal * 2, alignment: .leading)
                    .offset(x: CardInset.horizontal, y: CardInset.top)

                header(width: width)
                    .frame(height: 12)
                    .offset(y: headerY)

                divider.offset(y: dividerY)

                ForEach(Array(content.rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row, width: width, height: rowHeight)
                        .frame(height: rowHeight)
                        .offset(y: dividerY + 1 + CGFloat(index) * rowHeight)
                    if index < content.rows.count - 1 {
                        divider.offset(y: dividerY + CGFloat(index + 1) * rowHeight)
                    }
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .cardSurface(cornerRadius: Radius.panel)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: 1)
            .padding(.horizontal, CardInset.horizontal)
    }

    private func header(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            headerText("Layouts").position(x: Column.name, y: 6, anchor: .leading)
            headerText(content.columns[0]).position(x: width * Column.minimum, y: 6)
            headerText(content.columns[1]).position(x: width * Column.average, y: 6)
            headerText(content.columns[2]).position(x: width * Column.maximum, y: 6)
            headerText("What it means").position(x: width * Column.meaning, y: 6, anchor: .leading)
        }
    }

    private func headerText(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(Color(hex: 0xDBE7F0))
            .fixedSize()
    }

    private func rowView(_ row: AnalysisContent.Row, width: CGFloat, height: CGFloat) -> some View {
        let y = height / 2
        return ZStack(alignment: .leading) {
            Text(row.layout.name)
                .font(.system(size: 12))
                .foregroundStyle(.textPrimary)
                .fixedSize()
                .position(x: Column.name, y: y, anchor: .leading)
            metric(row.minimum).position(x: width * Column.minimum, y: y)
            metric(row.average).position(x: width * Column.average, y: y)
            metric(row.maximum).position(x: width * Column.maximum, y: y)
            Text(row.meaning)
                .font(.system(size: 12))
                .foregroundStyle(.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width * (1 - Column.meaning) - CardInset.horizontal, alignment: .leading)
                .position(x: width * Column.meaning, y: y, anchor: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func metric(_ metric: AnalysisContent.Metric) -> some View {
        VStack(spacing: 0) {
            Text(metric.value)
                .font(.system(size: 24, weight: metric.isHighlighted ? .bold : .light))
            if !content.unit.isEmpty {
                Text(content.unit(for: Double(metric.value) ?? 0))
                    .font(.system(size: 9, weight: metric.isHighlighted ? .medium : .regular))
                    .opacity(0.9)
            }
        }
        .foregroundStyle(metric.isHighlighted ? .textPrimary : .tableValueMuted)
        .fixedSize()
        .accessibilityValue(metric.isHighlighted ? "better" : "")
    }
}

private extension View {
    func position(x: CGFloat, y: CGFloat, anchor: UnitPoint) -> some View {
        fixedSize()
            .frame(width: 0, height: 0, alignment: anchor == .leading ? .leading : .center)
            .position(x: x, y: y)
    }
}

struct CardHeading: View {
    let title: String
    let measure: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                CardTitle(title)
                    .fixedSize()
                if !measure.isEmpty {
                    Text("· \(measure)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.textMuted)
                        .fixedSize()
                }
            }
            CardTitle(title)
                .fixedSize()
        }
    }
}
