import Foundation

/// The venue as the 3D view draws it: solid blocks, and the part of the layout they cover.
struct SimulationVenue {
    /// Changes when the venue does, so the GPU copy is only rebuilt then.
    let id: UUID
    let blocks: [VenueBlock]
    let plan: PlanFrame
    /// The middles of the booths and attractions, in layout meters. A visitor who stops turns to the nearest.
    var attractions: [SIMD2<Float>] = []
}

/// What the 3D view shows at one moment. Positions are in layout meters.
struct SimulationSceneFrame {
    struct Visitor {
        let id: Int
        let x: Double
        let z: Double
        let typeIndex: Int
        let people: Int
    }

    struct Spot {
        let number: Int
        let x: Double
        let z: Double
        /// 0 (calm) to 1 (jammed).
        let level: Double
        let grade: SeverityGrade
    }

    var visitors: [Visitor] = []
    /// Markers over the spots that are being watched, in the congestion view.
    var spots: [Spot] = []
    /// Crowd density or walked paths, laid flat over the floor.
    var overlay: FieldImage.Pixels?
}
