import SwiftUI

/// Splits the proposed width between two children, one third and two thirds. `containerRelativeFrame` reads the
/// container's width, and in a window that sizes itself to its content that feeds back until the window is thousands
/// of points wide. This layout only reads the width it is offered.
struct OneToTwoColumns: SwiftUI.Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: SwiftUI.LayoutSubviews, cache: inout ()) -> CGSize {
        let widths = columnWidths(in: proposal.width ?? 0)
        let heights = zip(subviews, widths).map { subview, width in
            subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        return CGSize(width: proposal.width ?? 0, height: heights.max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: SwiftUI.LayoutSubviews, cache: inout ()
    ) {
        var originX = bounds.minX
        for (subview, width) in zip(subviews, columnWidths(in: bounds.width)) {
            subview.place(
                at: CGPoint(x: originX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            originX += width + spacing
        }
    }

    private func columnWidths(in total: CGFloat) -> [CGFloat] {
        let usable = max(total - spacing, 0)
        return [usable / 3, usable * 2 / 3]
    }
}
