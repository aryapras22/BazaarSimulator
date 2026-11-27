import Foundation

/// One finished analysis, kept so the user can come back to it from the sidebar, also after the app was closed.
/// It holds copies of the layouts, the parameters, and the measurements the Analysis page reads, so later edits to
/// the project do not change it. The simulator's replay is not kept: it is large, and it is made again from the
/// same layout and parameters when a simulator opens.
struct SavedAnalysis: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    let number: Int
    let createdAt: Date
    let parameters: EventParameters
    let layouts: [Layout]
    let analyses: [LayoutAnalysis]
    /// Minute of the day the simulation showed the venue busiest.
    let peakMinute: Int

    init(
        id: UUID = UUID(),
        number: Int,
        createdAt: Date = Date(),
        parameters: EventParameters,
        layouts: [Layout],
        analyses: [LayoutAnalysis],
        peakMinute: Int
    ) {
        self.id = id
        self.name = "Run \(number)"
        self.number = number
        self.createdAt = createdAt
        self.parameters = parameters
        self.layouts = layouts
        self.analyses = analyses
        self.peakMinute = peakMinute
    }

    /// True when a run with these inputs would give the same analysis again.
    func matches(parameters: EventParameters, layouts: [Layout]) -> Bool {
        self.parameters == parameters
            && self.layouts.count == layouts.count
            && Set(self.layouts) == Set(layouts)
    }

    static func == (lhs: SavedAnalysis, rhs: SavedAnalysis) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
