import Foundation

enum CategoryChoice: Hashable, Sendable {
    static let seatingDisplayName = "Audience Seating"

    case booth(LegendEntry.ID?)
    case entertainment(EntertainmentType)
    case seating
}
