import SwiftUI

enum AnalysisTab: String, CaseIterable, Identifiable, Sendable {
    case congestionPoints
    case crowdDensity
    case congestionDuration
    case flowRate

    var id: String { rawValue }

    /// The tabs the Insights sheet offers. Flow Rate is still worked out but is not shown.
    static let shown: [AnalysisTab] = [.congestionPoints, .crowdDensity, .congestionDuration]

    var title: String {
        switch self {
        case .congestionPoints: "Stuck Spots"
        case .crowdDensity: "Crowd Level"
        case .congestionDuration: "Time Stuck"
        case .flowRate: "Flow Rate"
        }
    }

    var segmentWeight: CGFloat { 1 }
}
