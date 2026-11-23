import SwiftUI

enum Palette {
    static let background = Color(hex: 0x000C20)
    static let sidebarBase = Color(hex: 0x0B172B)
    static let glowBlue = Color(hex: 0x0E264F)
    static let glowOrange = Color(hex: 0x3C2A2B)
    static let surface = Color(hex: 0x121F36)
    /// The dim over the window behind a card that floats over it.
    static let scrim = Color.black.opacity(0.25)
    static let surfaceBorder = Color(hex: 0x223046)
    static let surfaceDisabled = Color(hex: 0x071329)
    static let surfaceDisabledBorder = Color(hex: 0x0E1A2F)
    static let control = Color(hex: 0x2F3946)
    static let controlDisabled = Color(hex: 0x131E2F)
    static let controlOnSurface = Color(hex: 0x253249)
    static let controlOnSurfaceBorder = Color(hex: 0x354359)
    static let field = Color(hex: 0x2D394D)
    static let fieldBorder = Color(hex: 0x354155)
    static let selection = Color(hex: 0x384458)
    static let selectionBorder = Color(hex: 0x485468)
    static let menu = Color(hex: 0x19253A)
    static let textPrimary = Color(hex: 0xDDDDDD)
    static let textSecondary = Color(hex: 0x929292)
    static let textTertiary = Color(hex: 0x848688)
    static let textDisabled = Color(hex: 0x585F6B)
    static let accent = Color(hex: 0x0066CC)
    static let accentIcon = Color(hex: 0x71ACE6)
    static let accentText = Color(hex: 0x659BD1)
    static let accentMuted = Color(hex: 0x306CB0)
    static let destructive = Color(hex: 0xF44245)
    static let primaryDisabled = Color(hex: 0x281B28)
    static let primaryDisabledText = Color(hex: 0x46444F)

    static let canvasGridLine = Color(hex: 0x071327)
    static let canvasBackgroundGrey = Color(hex: 0x212830)
    static let canvasGridLineGrey = Color(hex: 0x3A434F)
    static let canvasBackgroundWhite = Color(hex: 0xFFFFFF)
    static let canvasGridLineWhite = Color(hex: 0xDCE3EC)
    static let attractivenessSteps: [Color] = [
        Color(hex: 0xFCAD6B),
        Color(hex: 0xFD8D3B),
        Color(hex: 0xF2680F),
        Color(hex: 0xD84704),
        Color(hex: 0x8C2C04)
    ]
    static let canvasFloor = Color(hex: 0xFBFCFE)
    static let canvasLine = Color(hex: 0x1F4E86)
    static let canvasLabelOnDark = Color(hex: 0xFFFFFF)
    static let canvasGridOnFloor = Color(hex: 0x1F4E86, alpha: 0.10)
    static let canvasGridOnFloorMajor = Color(hex: 0x1F4E86, alpha: 0.18)
    static let canvasHatch = Color(hex: 0x1F4E86, alpha: 0.35)
    static let rulerMarker = accent
    static let canvasLineGlow = Color(hex: 0x2F6BB1, alpha: 0.4)
    static let canvasBoothFill = Color(hex: 0xF6F6F6)
    static let canvasOpenSide = Color(hex: 0xFFBCB0)
    static let canvasSelection = Color(hex: 0xF86323)
    static let canvasFlowFill = Color(hex: 0xD9ECF8)
    static let canvasFlowLine = Color(hex: 0x708EA9)
    static let canvasDoorFill = Color(hex: 0xF2CAB6)
    static let canvasDoorLine = Color(hex: 0xEB6547)
    static let canvasDoorSelected = Color(hex: 0xB72008)
    static let canvasIssue = destructive
    static let highlight = Color(hex: 0xF76222)
    static let actionOrange = Color(hex: 0xFF6A2A)
    static let visitorSeries1 = Color(hex: 0x0A80E1)
    static let visitorSeries2 = Color(hex: 0x13B6C7)
    static let visitorSeries3 = Color(hex: 0xDA8133)
    static let visitorSeries4 = Color(hex: 0xBD34D4)
    static let visitorSeriesColors = [visitorSeries1, visitorSeries2, visitorSeries3, visitorSeries4]
    static let fieldOnSurface = Color(hex: 0x3F4D64)
    static let fieldOnSurfaceBorder = Color(hex: 0x47556B)
    static let popoverOnSurface = Color(hex: 0x4F5D73)
    static let diagramFill = Color(hex: 0xC5CEDB)
    static let diagramChip = Color(hex: 0x525A65)
    static let tipBackground = Color(hex: 0x8CB5EB)
    static let tipText = Color(hex: 0x072955)
    static let tipButton = Color(hex: 0xBAE3FE)
    static let segmentedSelected = Color(hex: 0x3A485E)
    static let primaryDisabledOnSurface = Color(hex: 0x50313B)
    static let primaryDisabledOnSurfaceText = Color(hex: 0xA7999D)

    static let sceneFloor = Color(hex: 0xFFFFFF)
    static let sceneWall = Color(hex: 0xCAD5E2)
    static let scenePanel = Color(hex: 0xE8ECF2)
    static let sceneCounter = Color(hex: 0xCBD5E1)
    static let sceneSlab = Color(hex: 0x94A3B8)
    static let scenePillar = Color(hex: 0xCBD5E1)
    static let scenePlant = Color(hex: 0x22C55E)
    static let sceneSign = Color(hex: 0x3B82F6)

    static let heatLow = Color(hex: 0x70D364)
    static let heatMedium = Color(hex: 0xEFE810)
    static let heatOrange = Color(hex: 0xFB7E07)
    static let heatHigh = Color(hex: 0xF82D04)
    static let spotGlow = Color(hex: 0xFF2D2D)
}

extension ShapeStyle where Self == Color {
    static var heatLow: Color { Palette.heatLow }
    static var heatMedium: Color { Palette.heatMedium }
    static var heatOrange: Color { Palette.heatOrange }
    static var heatHigh: Color { Palette.heatHigh }
    static var spotGlow: Color { Palette.spotGlow }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0,
            opacity: alpha
        )
    }
}
