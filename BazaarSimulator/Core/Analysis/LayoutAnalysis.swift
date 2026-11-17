import Foundation
import simd

/// What the simulation measured at one monitored spot, all day.
struct SpotMeasurement: Codable, Sendable, Equatable {
    let number: Int
    let name: String
    /// Position in layout meters.
    let position: SIMD2<Double>
    /// People per m² of walkable floor, one value per sample from the moment the event opens.
    let densitySamples: [Float]
    /// People inside the spot, at the same samples.
    let peopleSamples: [Int]
}

/// Raw measurements of one simulated event in one layout. The Analysis feature turns these into
/// grades, headlines, and tables.
struct LayoutAnalysis: Codable, Sendable, Equatable {
    let layoutID: UUID
    /// Minutes from midnight when the event opens. Sample 0 and minute 0 are taken here.
    let eventStartMinute: Int
    let sampleIntervalSeconds: Int
    let spots: [SpotMeasurement]
    /// People passing the doors, per minute, from the moment the event opens.
    let flowPerMinute: [Double]
    /// How many people the run simulated, and how many the parameters asked for.
    let simulatedPeople: Int
    let totalPeople: Int
    /// The part of the layout the plan shows.
    var plan: PlanFrame = .unit
    /// Visitors and footfall through the busiest window, when the run had one.
    var replay: SimulationReplay?

    /// The replay is large and is made again from the layout and parameters when a simulator opens, so a stored
    /// analysis keeps the measurements only.
    private enum CodingKeys: String, CodingKey {
        case layoutID, eventStartMinute, sampleIntervalSeconds, spots, flowPerMinute
        case simulatedPeople, totalPeople, plan
    }
}
