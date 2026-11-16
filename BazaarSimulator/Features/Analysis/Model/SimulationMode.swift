import Foundation

/// What the simulator draws over the floor plan.
enum SimulationMode: String, CaseIterable, Identifiable {
    case congestion, density, footfall

    var id: Self { self }

    var title: String {
        switch self {
        case .congestion: "Congestion Grades"
        case .density: "Crowd Density"
        case .footfall: "Busiest Path"
        }
    }

    func summary(windowText: String) -> String {
        switch self {
        case .congestion: "Busiest window \(windowText)"
        case .density: "People per m² of aisle right now: green is comfortable, yellow crowded, red jammed."
        case .footfall: "How often each path has been walked since the window opened: green is rarely, red is the most."
        }
    }
}
