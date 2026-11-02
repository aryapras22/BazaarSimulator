import Foundation

enum LayoutIssueSeverity: String, Hashable, Sendable {
    case warning
    case error
}

enum LayoutIssueKind: Hashable, Sendable {
    case overlappingObjects
    case outsideFloor
    case blockedOpenSide(side: OpenSides)
    case noOpenSides
    case missingHallDoorEntry
    case missingHallDoorExit
    case belowMinimumSize
}

struct LayoutIssue: Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var severity: LayoutIssueSeverity
    var kind: LayoutIssueKind
    var objectIDs: [UUID]
    var message: String
}
