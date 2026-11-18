import SwiftUI

enum CardInset {
    static let horizontal: CGFloat = 22
    static let top: CGFloat = 22
    static let bottom: CGFloat = 18
}

enum LayoutCardInset {
    static let horizontal: CGFloat = 17
    static let top: CGFloat = 15
    static let bottom: CGFloat = 19
    static let legendLeading: CGFloat = 20
    static let legendTrailing: CGFloat = 28
}

struct CardTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    static let height: CGFloat = 16

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
            .frame(height: Self.height, alignment: .leading)
    }
}

enum CardSpacing {
    static let gap: CGFloat = 28
}

extension Radius {
    static let card: CGFloat = 26
    static let panel: CGFloat = 24
    static let tile: CGFloat = 10
    static let control: CGFloat = 8
}

private struct CardsAreGlassKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether the cards draw as glass instead of a solid fill. The Insights modal turns it on.
    var cardsAreGlass: Bool {
        get { self[CardsAreGlassKey.self] }
        set { self[CardsAreGlassKey.self] = newValue }
    }
}

struct CardSurface: ViewModifier {
    var cornerRadius: CGFloat = Radius.card
    @Environment(\.cardsAreGlass) private var cardsAreGlass

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if cardsAreGlass {
            content.glassEffect(.regular.tint(Color.cardSurface.opacity(0.45)), in: shape)
        } else {
            content.background {
                shape
                    .fill(Color.cardSurface)
                    .overlay { shape.strokeBorder(Color.cardBorder, lineWidth: 1) }
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }
        }
    }
}

extension View {
    func cardSurface(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(CardSurface(cornerRadius: cornerRadius))
    }
}

struct ControlButtonStyle: ButtonStyle {
    var fill: Color = .cardButtonFill
    var horizontalPadding: CGFloat = 16
    var minWidth: CGFloat? = nil

    static let height: CGFloat = 29

    func makeBody(configuration: Configuration) -> some View {
        ControlButtonBody(
            configuration: configuration,
            fill: fill,
            horizontalPadding: horizontalPadding,
            minWidth: minWidth
        )
    }

    private struct ControlButtonBody: View {
        let configuration: Configuration
        let fill: Color
        let horizontalPadding: CGFloat
        let minWidth: CGFloat?
        @State private var isHovered = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)

            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, horizontalPadding)
                .frame(minWidth: minWidth, minHeight: ControlButtonStyle.height, maxHeight: ControlButtonStyle.height)
                .background {
                    shape
                        .fill(fill)
                        .brightness(configuration.isPressed ? -0.04 : isHovered ? 0.04 : 0)
                        .overlay { shape.strokeBorder(Color.controlBorder.opacity(0.55), lineWidth: 0.75) }
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                }
                .contentShape(shape)
                .onHover { isHovered = $0 }
        }
    }
}

struct DashboardBackground: View {
    var spacing: CGFloat = 44
    var fill = Color.backgroundMain
    var line = Color.gridLine
    var lineWidth: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(line), lineWidth: lineWidth)
        }
        .background(fill)
        .accessibilityHidden(true)
    }
}

extension ShapeStyle where Self == Color {
    static var backgroundMain: Color { Color(hex: 0x000E29) }
    static var cardSurface: Color { Color(hex: 0x162B46) }
    static var cardSurfaceSecondary: Color { Color(hex: 0x3E4958) }
    static var cardBorder: Color { Color(hex: 0x223955) }
    static var divider: Color { Color(hex: 0x324053) }
    static var gridLine: Color { Color(hex: 0x0B1B36) }

    static var headerButtonFill: Color { Color(hex: 0x3A4A5F) }
    static var cardButtonFill: Color { Color(hex: 0x354860) }
    static var backButtonFill: Color { Color(hex: 0x212433) }
    static var controlBorder: Color { Color(hex: 0x56677F) }
    static var segmentTrack: Color { Color(hex: 0x162B46) }
    static var segmentSelected: Color { Color(hex: 0x5F6E82) }
    static var segmentSelectedBorder: Color { Color(hex: 0x76859A) }
    static var linkBlue: Color { Color(hex: 0xADC5E5) }

    static var textPrimary: Color { Color(hex: 0xE3E9F2) }
    static var textSecondary: Color { Color(hex: 0xC1CDDC) }
    static var textMuted: Color { Color(hex: 0xA1ADB9) }
    static var tableValueMuted: Color { Color(hex: 0xA4ACB4) }
    static var textOnLight: Color { Color(hex: 0x1A0F08) }

    static var layout1: Color { Color(hex: 0xFF7F33) }
    static var layout1Tile: Color { Color(hex: 0xFE6A29) }
    static var layout2: Color { Color(hex: 0x007DD5) }
    static var layout2Chart: Color { Color(hex: 0x56A6FD) }
    static var chartGrid: Color { Color(hex: 0x223552) }

    static var visitorOutline: Color { Color(hex: 0x0B1830) }

    static var heatLow: Color { Color(hex: 0x70D364) }
    static var heatMedium: Color { Color(hex: 0xEFE810) }
    static var heatOrange: Color { Color(hex: 0xFB7E07) }
    static var heatHigh: Color { Color(hex: 0xF82D04) }

    static var hotspotSevere: Color { Color(hex: 0xE5483B) }
    static var spotGlow: Color { Color(hex: 0xFF2D2D) }

    static var gradeA: Color { Color(hex: 0x55B049) }
    static var gradeB: Color { Color(hex: 0x788938) }
    static var gradeC: Color { Color(hex: 0x926C2B) }
    static var gradeD: Color { Color(hex: 0xB24A1C) }
    static var gradeE: Color { Color(hex: 0xCE2A0E) }
    static var gradeF: Color { Color(hex: 0xA00700) }
}
