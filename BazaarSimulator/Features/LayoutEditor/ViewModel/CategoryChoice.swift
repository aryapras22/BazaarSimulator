import Foundation

enum CategoryChoice: Hashable, Sendable {
    case booth(BoothType?)
    case entertainment(EntertainmentType)
}
