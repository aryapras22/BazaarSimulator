import Foundation

/// One finished parameter run, kept so the user can come back to it from the sidebar, also after the app was closed.
/// It holds copies of the layouts, the parameters, and the measurements the Analysis page reads, so later edits to
/// the project do not change it. The recorded footage is not kept: it is large and only the 3D replay needs it.
struct SavedAnalysis: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    let number: Int
    let createdAt: Date
    let parameters: EventParameters
    let layouts: [Layout]
    let measurements: [LayoutAnalysis]
    /// Minute of the day with the most people inside, in the first layout.
    let peakMinute: Int

    init(
        id: UUID = UUID(),
        number: Int,
        createdAt: Date = Date(),
        parameters: EventParameters,
        layouts: [Layout],
        measurements: [LayoutAnalysis],
        peakMinute: Int
    ) {
        self.id = id
        self.name = "Run \(number)"
        self.number = number
        self.createdAt = createdAt
        self.parameters = parameters
        self.layouts = layouts
        self.measurements = measurements
        self.peakMinute = peakMinute
    }
}

extension LayoutAnalysis: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(layoutID)
        hasher.combine(eventStartMinute)
        hasher.combine(simulatedPeople)
    }
}
