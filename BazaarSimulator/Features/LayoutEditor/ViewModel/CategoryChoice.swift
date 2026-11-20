import Foundation

enum CategoryChoice: Hashable, Sendable {
    case booth(LegendEntry.ID?)
    case entertainment(EntertainmentType)
}
