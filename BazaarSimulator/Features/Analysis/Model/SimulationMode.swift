import Foundation

/// What the simulator draws over the floor plan.
enum SimulationMode: String, CaseIterable, Identifiable {
    case congestion, density, footfall

    var id: Self { self }

    var title: String {
        switch self {
        case .congestion: "Congestion Spots"
        case .density: "Crowd Level"
        case .footfall: "Walking Routes"
        }
    }

    func summary(windowText: String) -> String {
        switch self {
//        case .congestion: "Numbered spots are where people get stuck. Click one to see why."
        case .congestion: "Numbered spots are where people get stuck."
        case .density: "Colours show how packed each part of the floor gets as people walk in."
        case .footfall: "Lines show the paths people take. Red lines are walked the most."
        }
    }
}
