import SwiftUI

enum Typography {
    static let title: Font = .system(size: 22, weight: .bold)
    static let subtitle: Font = .system(size: 12, weight: .regular)
    static let fieldLabel: Font = .system(size: 14, weight: .semibold)
    static let sectionLabel: Font = .system(size: 11, weight: .regular)
    static let body: Font = .system(size: 13, weight: .regular)
    static let caption: Font = .system(size: 11, weight: .regular)
    static let emptyTitle: Font = .system(size: 15, weight: .semibold)
    static let panelTitle: Font = .system(size: 17, weight: .semibold)
    static let inspectorLabel: Font = .system(size: 12, weight: .semibold)
    static let inspectorLabelDetail: Font = .system(size: 12, weight: .regular)
    static let segment: Font = .system(size: 13, weight: .medium)
    static let canvasLabel: Font = .system(size: 9, weight: .medium)
    static let logLine: Font = .system(size: 11, weight: .regular, design: .monospaced)

    static func canvasLabel(scaledBy scale: Double) -> Font {
        let clampedSize = min(max(9.0 * (scale / 12.0), 8.0), 14.0)
        return .system(size: clampedSize, weight: .medium)
    }
}
