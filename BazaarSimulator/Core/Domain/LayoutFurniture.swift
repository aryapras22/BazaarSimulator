import Foundation

enum LayoutFurnitureKind: String, Codable, Hashable, Sendable {
    case table
    case chair
}

/// Tables and chairs read from a plan. They are kept apart from `LayoutObject` so editing, validation and
/// hit-testing leave them alone, and the crowd simulation can read them as they were drawn.
struct LayoutFurniture: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: LayoutFurnitureKind
    var placement: Placement
    /// The table a chair belongs to. Chairs in audience rows have none.
    var tableID: UUID?

    init(
        id: UUID = UUID(),
        kind: LayoutFurnitureKind,
        placement: Placement,
        tableID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.placement = placement
        self.tableID = tableID
    }
}
