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
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { onOutsideTap?() }

                ViewThatFits(in: .vertical) {
                    content(width)
                    ScrollView { content(width) }
                }
                .frame(width: width)
                // A frosted layer under the glass, so what shows through the card is blurred more.
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.vertical, margin)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .transition(.opacity)
    }
}
