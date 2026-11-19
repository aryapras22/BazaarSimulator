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
    static let summaryHeight: CGFloat = 190
    /// The Result bar under a single layout has no "why" row, so it is lower.
    static let singleSummaryHeight: CGFloat = 168

    static let referencePlanHeight: CGFloat = 425
    static let referenceLowerHeight: CGFloat = 433
    static let minimumLowerHeight: CGFloat = RecommendationCard.fixedHeight + 12 + 18 + minimumTileHeight
    static let minimumTileHeight: CGFloat = 184

    let progress: CGFloat
    let contentWidth: CGFloat

    let planHeight: CGFloat
    let lowerHeight: CGFloat
    let recommendationWidth: CGFloat

    init(size: CGSize, layoutCount: Int = 2) {
        let progress = min(max((size.height - 900) / (Self.referenceHeight - 900), 0), 1)
        self.progress = progress
        contentWidth = size.width - Self.horizontalPadding.leading - Self.horizontalPadding.trailing

        func lerp(_ compact: CGFloat, _ regular: CGFloat) -> CGFloat { compact + (regular - compact) * progress }

        let cardChrome = LayoutCardInset.top + ControlButtonStyle.height + lerp(18, 28) + 3
            + SeverityScaleView.labelHeight + SeverityScaleView.labelSpacing + SeverityScaleView.barHeight
            + LayoutCardInset.bottom
        let fixed = lerp(16, 29) + Self.headerHeight + lerp(14, 25)
            + cardChrome
            + lerp(16, 26) + Self.analysisTitleHeight + lerp(12, 20) + Self.tabBarHeight + lerp(16, 29)
            + lerp(18, 32)
        let available = max(size.height - fixed, 0)

        let cardWidth = layoutCount == 1 ? contentWidth : (contentWidth - Self.cardGap) / 2
        let widthLimitedPlan = (cardWidth - LayoutCardInset.horizontal * 2) / FloorPlan.aspectRatio
        let lower = min(max(available * Self.referenceLowerHeight / (Self.referencePlanHeight + Self.referenceLowerHeight),
                            Self.minimumLowerHeight), Self.referenceLowerHeight)
        // The Insights tabs are laid out at the reference size, which is where this part is read.
        let tabsPlan = max(min(available - lower, Self.referencePlanHeight, widthLimitedPlan), 160)
        lowerHeight = max(available - tabsPlan, lower)

        // On the page itself the plan takes the room the header and the Best Layout summary leave.
        // With two layouts the row under each plan, which only the single layout fills, is left out, so the plans get
        // its room.
        let underPlanRow = SeverityScaleView.labelHeight + SeverityScaleView.labelSpacing + SeverityScaleView.barHeight + 3
        let pageFixed = lerp(16, 29) + Self.headerHeight + lerp(14, 25)
            + (layoutCount == 1 ? cardChrome : cardChrome - underPlanRow)
            + lerp(16, 24) + (layoutCount == 1 ? Self.singleSummaryHeight : Self.summaryHeight) + lerp(16, 26)
        planHeight = max(min(size.height - pageFixed, widthLimitedPlan), 200)
        recommendationWidth = contentWidth * 509 / 1143
    }

    private func lerp(_ compact: CGFloat, _ regular: CGFloat) -> CGFloat {
        compact + (regular - compact) * progress
    }

    var topPadding: CGFloat { lerp(16, 29) }
    var headerToCards: CGFloat { lerp(14, 25) }
    var cardsToSummary: CGFloat { lerp(16, 24) }
    var bottomPadding: CGFloat { lerp(16, 26) }
    var cardsToAnalysis: CGFloat { lerp(16, 26) }
    var titleToTabs: CGFloat { lerp(12, 20) }
    var tabsToLower: CGFloat { lerp(16, 29) }

    var planTopPadding: CGFloat { lerp(18, 28) }

    var tableHeight: CGFloat { (lowerHeight - Self.cardGap) / 2 }

    var headlineToTiles: CGFloat { lerp(12, 21) }
    var tilesToLink: CGFloat { lerp(18, 38) }
    var tileHeight: CGFloat {
        let chrome = RecommendationCard.fixedHeight + headlineToTiles + tilesToLink
        return max(lowerHeight - chrome, Self.minimumTileHeight)
    }
}
