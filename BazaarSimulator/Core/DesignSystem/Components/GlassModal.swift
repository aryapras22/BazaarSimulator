import SwiftUI

/// A glass card centered over the whole window, with the rest dimmed. It is drawn by the app root over the blurred
/// window, not as a sheet, so its glass has the window to show. The card is as tall as its content, and scrolls when
/// the window is shorter than that.
struct GlassModal<Content: View>: View {
    /// The widest the card gets. In a narrower window it shrinks to fit with a margin.
    var maxWidth: CGFloat
    /// Called when the dimmed area outside the card is clicked. Nothing happens when this is nil.
    var onOutsideTap: (() -> Void)?
    @ViewBuilder var content: (_ width: CGFloat) -> Content

    var body: some View {
        GeometryReader { geometry in
            let margin = Spacing.xl
            let width = min(maxWidth, geometry.size.width - margin * 2)
            ZStack {
                Palette.scrim
                    .ignoresSafeArea()
                    .onTapGesture { onOutsideTap?() }

                ViewThatFits(in: .vertical) {
                    content(width)
                    ScrollView { content(width) }
                }
                .frame(width: width)
                .glassCardSurface(in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
                .padding(.vertical, margin)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .transition(.opacity)
    }
}

extension View {
    /// A frosted material under Liquid Glass, matching `GlassModal` so floating cards blur what sits behind them.
    func glassCardSurface<S: Shape>(in shape: S) -> some View {
        self
            .background(.regularMaterial, in: shape)
            .glassEffect(.regular, in: shape)
    }
}

private struct GlassModalPreviewCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(Typography.title)
                .foregroundColor(Palette.textPrimary)
            Text(message)
                .font(Typography.subtitle)
                .foregroundColor(Palette.textSecondary)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Normal") {
    GlassModal(maxWidth: 480) { _ in
        GlassModalPreviewCard(title: "Insights", message: "Each tab compares the layouts on one result.")
    }
    .frame(width: 640, height: 420)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    GlassModal(maxWidth: 480) { _ in
        GlassModalPreviewCard(
            title: "A title that is long enough to wrap onto a second line in a narrow card",
            message: String(repeating: "A long message that goes on and on. ", count: 12)
        )
    }
    .frame(width: 640, height: 420)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    GlassModal(maxWidth: 480) { _ in
        GlassModalPreviewCard(title: "", message: "")
    }
    .frame(width: 640, height: 420)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    GlassModal(maxWidth: 480, onOutsideTap: {}) { _ in
        GlassModalPreviewCard(title: "Parameters", message: "Applies to every layout in this project.")
    }
    .frame(width: 640, height: 420)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    GlassModal(maxWidth: 480) { _ in
        GlassModalPreviewCard(title: "Insights", message: "Nothing to compare yet.")
            .disabled(true)
    }
    .frame(width: 640, height: 420)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
