import Foundation

/// The buttons floating beside the inspector. Each starts adding one kind of element: the Floor Plan tab adds a
/// booth or audience seating, and the Structure tab draws a wall, places an object or a door, or marks a restricted area.
enum EditorAddTool: CaseIterable, Identifiable, Sendable {
    enum Icon: Sendable {
        case system(String)
        case asset(String)
    }

    case booth
    case chair
    case wall
    case block
    case door
    case restrictedArea

    var id: Self { self }

    var layer: EditorLayer {
        switch self {
        case .booth, .chair: .booths
        case .wall, .block, .door, .restrictedArea: .structure
        }
    }

    var title: String {
        switch self {
        case .booth: "Add booth"
        case .chair: "Add chair"
        case .wall: "Draw wall"
        case .block: "Add object"
        case .door: "Add door"
        case .restrictedArea: "Mark restricted area"
        }
    }

    var icon: Icon {
        switch self {
        case .booth: .asset("BoothIcon")
        case .chair: .system("chair.fill")
        case .wall: .asset("WallIcon")
        case .block: .system("square.fill")
        case .door: .system("door.left.hand.closed")
        case .restrictedArea: .asset("BarrierIcon")
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
        case .chair:
            return ObjectCatalog.defaultItemID(for: .seating).map { .place(.catalog($0)) }
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
