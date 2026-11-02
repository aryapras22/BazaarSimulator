import SwiftUI

enum Palette {
    static let background = Color(hex: 0x000C20)
    static let sidebarBase = Color(hex: 0x0B172B)
    static let glowBlue = Color(hex: 0x0E264F)
    static let glowOrange = Color(hex: 0x3C2A2B)
    static let surface = Color(hex: 0x121F36)
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
