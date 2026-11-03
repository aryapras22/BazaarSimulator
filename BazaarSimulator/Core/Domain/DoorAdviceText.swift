import Foundation

struct DoorAdvice: Hashable, Sendable {
    let message: String
    let actionTitle: String
    let suggestedDirection: DoorDirection
}

enum DoorAdviceText {
    static func noEntry(doorLabel: String) -> DoorAdvice {
        DoorAdvice(
            message: "No door lets visitors in. Make \(doorLabel) an entrance?",
            actionTitle: "Use \"Entrance\"",
            suggestedDirection: .entrance
        )
    }

    static func noExit(doorLabel: String) -> DoorAdvice {
        DoorAdvice(
            message: "No door lets visitors out. Make \(doorLabel) an exit?",
            actionTitle: "Use \"Exit\"",
            suggestedDirection: .exit
        )
    }

    static func widestDisabled(doorLabel: String) -> DoorAdvice {
        DoorAdvice(
            message: "\(doorLabel) is the widest door. Disabling it slows the crowd. Make it Both?",
            actionTitle: "Use \"Both\"",
            suggestedDirection: .both
        )
    }

    static func pairWithExitOnly(otherDoorLabel: String, selectedDoorLabel: String) -> DoorAdvice {
        DoorAdvice(
            message: "\(otherDoorLabel) is already an exit. Most bazaars use one main entry. " +
                "Make \(selectedDoorLabel) an entrance?",
            actionTitle: "Use \"Entrance\"",
            suggestedDirection: .entrance
        )
    }
}
