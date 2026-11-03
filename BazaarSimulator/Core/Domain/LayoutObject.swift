import Foundation

enum ReviewState: String, Codable, Hashable, Sendable {
    case detected
    case confirmed
}

struct LayoutObject: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: LayoutObjectKind
    var label: String
    var placement: Placement
    var categoryID: LegendEntry.ID?
    var openSides: OpenSides
    var doorFlow: DoorFlow?
    var reviewState: ReviewState

    init(
        id: UUID = UUID(),
        kind: LayoutObjectKind,
        label: String,
        placement: Placement,
        categoryID: LegendEntry.ID? = nil,
        openSides: OpenSides = [],
        doorFlow: DoorFlow? = nil,
        reviewState: ReviewState = .confirmed
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.placement = placement
        self.categoryID = categoryID
        self.openSides = openSides
        self.doorFlow = doorFlow
        self.reviewState = reviewState
    }
}
