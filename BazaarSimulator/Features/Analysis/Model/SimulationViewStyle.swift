import Foundation

/// How the simulator shows the venue: the flat plan, or a 3D scene you can orbit.
enum SimulationViewStyle: String, CaseIterable, Identifiable {
    case twoD, threeD

    var id: Self { self }

    var title: String {
        switch self {
        case .twoD: "2D"
        case .threeD: "3D"
        }
    }
}
