import Foundation

enum AnalysisTab: String, CaseIterable, Identifiable, Sendable {
    case congestionPoints
    case congestionDuration
    case crowdDensity
    case flowRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .congestionPoints: "Congestion Points"
        case .congestionDuration: "Congestion Duration"
        case .crowdDensity: "Crowd Density"
        case .flowRate: "Flow Rate"
        }
    }

    var segmentWeight: CGFloat {
        switch self {
        case .congestionPoints: 299
        case .congestionDuration: 306
        case .crowdDensity: 302
        case .flowRate: 238
        }
    }
}
