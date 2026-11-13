import Foundation

/// What a simulation window shows: one layout of one run, as the card in slot `slot` shows it.
/// A value, so the app can open and restore the window from it.
struct SimulationTarget: Codable, Hashable, Sendable {
    let projectID: UUID
    let layoutID: UUID
    /// Which card the layout was on, which fixes its name and color.
    let slot: LayoutID
    /// The saved analysis to play. Nil plays the latest.
    var analysisID: UUID?
}

/// What a visitor is doing, as one entry of the simulation's legend.
struct VisitorType: Identifiable, Sendable, Equatable {
    let id: Int
    let name: String

    /// One entry per state the engine reports, in the order the replay indexes them.
    static let all = VisitorState.allCases.enumerated().map { VisitorType(id: $0, name: $1.label) }
}
