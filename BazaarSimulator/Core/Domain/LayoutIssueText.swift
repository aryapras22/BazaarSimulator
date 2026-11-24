import Foundation

enum LayoutIssueText {
    static func overlappingObjects(_ firstLabel: String, _ secondLabel: String) -> String {
        "\(firstLabel) overlaps \(secondLabel)"
    }

    static func outsideFloor(_ label: String) -> String {
        "\(label) sits outside the hall and lobby"
    }

    static func blockedOpenSide(_ label: String, sideName: String) -> String {
        "Open \(sideName.lowercased()) side of \(label) faces an obstacle"
    }

    static func noOpenSides(_ label: String) -> String {
        "Visitors cannot reach \(label)"
    }

    static func belowMinimumSize(_ label: String) -> String {
        "\(label) is below the minimum size"
    }

    static let missingHallDoorEntry = "No hall door allows visitors to enter"
    static let missingHallDoorExit = "No hall door allows visitors to exit"
}
