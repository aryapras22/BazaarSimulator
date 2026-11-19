import Foundation

/// The buttons floating beside the inspector. Each starts adding one kind of element: the Floor Plan tab adds a
/// booth, a table, or an entertainment attraction, and the Structure tab draws a wall, places an object or a door, or
/// marks a restricted area.
enum EditorAddTool: CaseIterable, Identifiable, Sendable {
    case booth
    case table
    case entertainment
    case wall
    case block
    case door
    case restrictedArea

    var id: Self { self }

    var layer: EditorLayer {
        switch self {
        case .booth, .table, .entertainment: .booths
        case .wall, .block, .door, .restrictedArea: .structure
        }
    }

    var title: String {
        switch self {
        case .booth: "Add booth"
        case .table: "Add table"
        case .entertainment: "Add entertainment"
        case .wall: "Draw wall"
        case .block: "Add object"
        case .door: "Add door"
        case .restrictedArea: "Mark restricted area"
        }
    }

    var systemImage: String {
        switch self {
        case .booth: "storefront"
        case .table: "chair"
        case .entertainment: "music.mic"
        case .wall: "rectangle.split.3x3"
        case .block: "square.fill"
        case .door: "door.left.hand.open"
        case .restrictedArea: "nosign"
        }
    }

    static func tools(for layer: EditorLayer) -> [EditorAddTool] {
        allCases.filter { $0.layer == layer }
    }
}

extension LayoutEditorViewModel {
    /// The tool a button switches on. Nil when there is nothing to add yet, such as a booth before any legend color.
    func tool(for item: EditorAddTool) -> EditorTool? {
        switch item {
        case .booth:
            return cachedBoothTemplates.first.map { .place(.template($0)) }
        case .table:
            return ObjectCatalog.defaultItemID(for: .table).map { .place(.catalog($0)) }
        case .entertainment:
            return .place(.catalog(ObjectCatalog.entertainmentID))
        case .wall:
            return .drawWall(itemID: selectedWallItemID)
        case .block:
            return ObjectCatalog.defaultItemID(for: .block).map { .place(.catalog($0)) }
        case .door:
            return ObjectCatalog.defaultItemID(for: .door).map { .placeDoor(itemID: $0) }
        case .restrictedArea:
            return .blockedArea
        }
    }

    /// Whether the tool of a button is the one in use. Any booth stamp counts for the booth button, since the
    /// library can have switched it to another color.
    func isActive(_ item: EditorAddTool) -> Bool {
        switch (item, tool) {
        case (.booth, .place(.template)): return true
        case (.wall, .drawWall): return true
        case (.door, .placeDoor): return true
        default: return tool(for: item) == tool
        }
    }

    /// Switches the button's tool on, or off again, back to selecting, when it is already on.
    func toggle(_ item: EditorAddTool) {
        if isActive(item) {
            selectTool(.select)
            return
        }
        guard item.layer == activeLayer, let next = tool(for: item) else { return }
        selectObject(nil)
        selectTool(next)
    }
}
