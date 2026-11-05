import SwiftUI

struct RecommendationCard: View {
    let tab: AnalysisTab
    let content: AnalysisContent
    var metrics: DashboardMetrics = .reference

    @State private var showsExplanation = false

    static let fixedHeight: CGFloat = inset.top + titleHeight + 16 + nameHeight + 14 + headlineHeight + linkHeight + inset.bottom
    private static let inset = (top: CGFloat(23), leading: CGFloat(29), trailing: CGFloat(34), bottom: CGFloat(18))
    private static let titleHeight: CGFloat = 16
    private static let nameHeight: CGFloat = 38
    private static let headlineHeight: CGFloat = 30
    private static let linkHeight: CGFloat = 14
    private static let iconColumnWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Best \(tab.title)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.textPrimary)
                .frame(height: Self.titleHeight)

            HStack(spacing: 14) {
                Circle()
                    .fill(content.recommended.accent)
                    .frame(width: 10, height: 10)
                    .shadow(color: content.recommended.accent.opacity(0.8), radius: 4)
                Text(content.recommended.name)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.textPrimary)
            }
            .frame(height: Self.nameHeight)
            .padding(.top, 16)

            Text(content.headline)
                .font(.system(size: 12))
                .foregroundStyle(.textPrimary)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: RecommendationCard.headlineWidth, alignment: .leading)
                .frame(height: Self.headlineHeight, alignment: .topLeading)
                .padding(.top, 14)
                .padding(.trailing, Self.iconColumnWidth - 30)

            HStack(alignment: .top, spacing: 14) {
                ForEach(content.tiles) { tile in
                    OutcomeTileView(tile: tile, isRecommended: tile.layout == content.recommended)
                }
            }
            .frame(height: metrics.tileHeight)
            .padding(.top, metrics.headlineToTiles)

            Button {
                showsExplanation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(content.infoQuestion)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.linkBlue)
                .frame(height: Self.linkHeight)
            }
            .buttonStyle(.plain)
            .padding(.top, metrics.tilesToLink)
            .popover(isPresented: $showsExplanation, arrowEdge: .top) {
                ExplanationPopover(title: tab.title, content: content)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, Self.inset.top)
        .padding(.leading, Self.inset.leading)
        .padding(.trailing, Self.inset.trailing)
        .padding(.bottom, Self.inset.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 9) {
                Image(systemName: content.symbol)
                    .font(.system(size: 36, weight: .regular))
                    .frame(height: 36)
                Text(tab.title)
                    .font(.system(size: 10))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundStyle(.textPrimary)
            .frame(width: Self.iconColumnWidth)
            .padding(.top, 57)
            .padding(.trailing, 46)
            .accessibilityElement(children: .combine)
        }
        .cardSurface()
    }

    static let headlineWidth: CGFloat = 290
}

struct OutcomeTileView: View {
    let tile: AnalysisContent.Tile
    let isRecommended: Bool

    var body: some View {
        let foreground: Color = isRecommended ? tile.layout.onTileFill : .textPrimary

        VStack(alignment: .leading, spacing: 0) {
            Text(tile.layout.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(height: 15)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(tile.value)
                    .font(.system(size: 28, weight: .semibold))
                if !tile.unit.isEmpty {
                    Text(tile.unit)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.top, 4)

            Text(tile.caption)
                .font(.system(size: 11.5))
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: 150, alignment: .leading)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text("What this means:")
                    .fontWeight(.semibold)
                ForEach(tile.bullets, id: \.self) { bullet in
                    Text("- \(bullet)")
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.system(size: 11.5))
            .padding(.top, 19)
        }
        .foregroundStyle(foreground)
        .padding(.top, 17)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            if isRecommended {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(tile.layout.tileFill, .white)
                    .padding(.top, 15)
                    .padding(.trailing, 14)
                    .help("Better choice")
                    .accessibilityLabel("Better choice")
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(isRecommended ? tile.layout.tileFill : Color.cardSurfaceSecondary)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExplanationPopover: View {
    let title: String
    let content: AnalysisContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(content.explanation)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }

            if !content.facts.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(content.facts) { fact in
                        HStack(spacing: 10) {
                            Image(systemName: fact.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 16)
                            Text(fact.text)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .frame(height: 16)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }
}
