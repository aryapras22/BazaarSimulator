import Foundation

enum LayoutIssueText {
    static func overlappingObjects(_ firstLabel: String, _ secondLabel: String) -> String {
        "\(firstLabel) overlaps \(secondLabel)"
    }

    static func outsideFloor(_ label: String) -> String {
        "\(label) sits outside the hall and lobby"
    }

    static func blockedOpenSide(_ sideName: String) -> String {
        "Open \(sideName.lowercased()) side faces an obstacle"
    }

    static let noOpenSides = "Visitors cannot reach this booth"
    static let missingHallDoorEntry = "No hall door allows visitors to enter"
    static let missingHallDoorExit = "No hall door allows visitors to exit"
    static let belowMinimumSize = "Size is below the minimum allowed"
}
