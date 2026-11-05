import SwiftUI

struct AnalysisSection: View {
    @Binding var tab: AnalysisTab
    let content: AnalysisContent
    var metrics: DashboardMetrics = .reference

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Analysis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(height: DashboardMetrics.analysisTitleHeight)

            SegmentedTabBar(
                options: AnalysisTab.allCases,
                selection: $tab,
                title: \.title,
                weight: \.segmentWeight
            )
            .accessibilityLabel("Analysis metric")
            .padding(.top, metrics.titleToTabs)

            HStack(alignment: .top, spacing: CardSpacing.gap) {
                RecommendationCard(tab: tab, content: content, metrics: metrics)
                    .frame(width: metrics.recommendationWidth)

                VStack(spacing: CardSpacing.gap) {
                    MetricsTableCard(content: content)
                        .frame(height: metrics.tableHeight)
                    AnalysisChartCard(content: content)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: metrics.lowerHeight)
            .padding(.top, metrics.tabsToLower)
        }
    }
}

struct SegmentedTabBar<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var weight: (Option) -> CGFloat = { _ in 1 }
    var style = SegmentedTabBarStyle()

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let totalWeight = options.reduce(0) { $0 + weight($1) }

            HStack(spacing: 0) {
                ForEach(options) { option in
                    let isSelected = option == selection
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                            selection = option
                        }
                    } label: {
                        Text(title(option))
                            .font(.system(size: 14, weight: isSelected ? .semibold : style.unselectedWeight))
                            .foregroundStyle(isSelected ? Color.white : Color(hex: 0xC7CED9))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: style.pillRadius, style: .continuous)
                                        .fill(style.pill)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: style.pillRadius, style: .continuous)
                                                .strokeBorder(style.pillBorder, lineWidth: 0.75)
                                        }
                                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                                        .padding(style.pillInset)
                                        .matchedGeometryEffect(id: "selection", in: namespace)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: geometry.size.width * weight(option) / totalWeight)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .frame(height: style.height)
        .background {
            RoundedRectangle(cornerRadius: style.trackRadius, style: .continuous)
                .fill(style.track)
                .overlay {
                    RoundedRectangle(cornerRadius: style.trackRadius, style: .continuous)
                        .strokeBorder(style.trackBorder, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }
}

struct SegmentedTabBarStyle {
    var height = DashboardMetrics.tabBarHeight
    var trackRadius: CGFloat = 10
    var pillRadius: CGFloat = 8
    var pillInset: CGFloat = 2
    var track = Color.segmentTrack
    var trackBorder = Color.cardBorder
    var pill: AnyShapeStyle = AnyShapeStyle(Color.segmentSelected)
    var pillBorder = Color.segmentSelectedBorder
    var unselectedWeight: Font.Weight = .medium
}
