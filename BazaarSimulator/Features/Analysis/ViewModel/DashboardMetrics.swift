//
//  DashboardMetrics.swift
//  Challenge 5
//

import CoreGraphics

struct DashboardMetrics {
    static let referenceHeight: CGFloat = 1268
    static let reference = DashboardMetrics(size: CGSize(width: 1197, height: referenceHeight))

    static let horizontalPadding = (leading: CGFloat(28), trailing: CGFloat(26))
    static let headerHeight: CGFloat = 40
    static let analysisTitleHeight: CGFloat = 24
    static let tabBarHeight: CGFloat = 35
    static let cardGap: CGFloat = 28

    static let referencePlanHeight: CGFloat = 425
    static let referenceLowerHeight: CGFloat = 433
    static let minimumLowerHeight: CGFloat = RecommendationCard.fixedHeight + 12 + 18 + minimumTileHeight
    static let minimumTileHeight: CGFloat = 184

    let progress: CGFloat
    let contentWidth: CGFloat

    let planHeight: CGFloat
    let lowerHeight: CGFloat
    let recommendationWidth: CGFloat

    init(size: CGSize) {
        let progress = min(max((size.height - 900) / (Self.referenceHeight - 900), 0), 1)
        self.progress = progress
        contentWidth = size.width - Self.horizontalPadding.leading - Self.horizontalPadding.trailing

        func lerp(_ compact: CGFloat, _ regular: CGFloat) -> CGFloat { compact + (regular - compact) * progress }

        let cardChrome = LayoutCardInset.top + ControlButtonStyle.height + lerp(20, 41) + 3
            + SeverityScaleView.labelHeight + SeverityScaleView.labelSpacing + SeverityScaleView.barHeight
            + LayoutCardInset.bottom
        let fixed = lerp(16, 29) + Self.headerHeight + lerp(14, 25)
            + cardChrome
            + lerp(16, 26) + Self.analysisTitleHeight + lerp(12, 20) + Self.tabBarHeight + lerp(16, 29)
            + lerp(18, 32)
        let available = max(size.height - fixed, 0)

        let cardWidth = (contentWidth - Self.cardGap) / 2
        let widthLimitedPlan = (cardWidth - LayoutCardInset.horizontal * 2) / FloorPlan.aspectRatio
        let lower = min(max(available * Self.referenceLowerHeight / (Self.referencePlanHeight + Self.referenceLowerHeight),
                            Self.minimumLowerHeight), Self.referenceLowerHeight)
        planHeight = max(min(available - lower, Self.referencePlanHeight, widthLimitedPlan), 160)
        lowerHeight = max(available - planHeight, lower)
        recommendationWidth = contentWidth * 509 / 1143
    }

    private func lerp(_ compact: CGFloat, _ regular: CGFloat) -> CGFloat {
        compact + (regular - compact) * progress
    }

    var topPadding: CGFloat { lerp(16, 29) }
    var headerToCards: CGFloat { lerp(14, 25) }
    var cardsToAnalysis: CGFloat { lerp(16, 26) }
    var titleToTabs: CGFloat { lerp(12, 20) }
    var tabsToLower: CGFloat { lerp(16, 29) }

    var planTopPadding: CGFloat { lerp(20, 41) }

    var tableHeight: CGFloat { (lowerHeight - Self.cardGap) / 2 }

    var headlineToTiles: CGFloat { lerp(12, 21) }
    var tilesToLink: CGFloat { lerp(18, 38) }
    var tileHeight: CGFloat {
        let chrome = RecommendationCard.fixedHeight + headlineToTiles + tilesToLink
        return max(lowerHeight - chrome, Self.minimumTileHeight)
    }
}
