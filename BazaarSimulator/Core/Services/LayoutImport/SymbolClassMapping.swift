import Foundation

/// What a symbol class from the legend library becomes in a layout. Classes outside the table fall back to the
/// extractor's own class, so a symbol never decides which items exist, only how they are drawn.
enum SymbolClassMapping {
    enum Outcome: Equatable {
        case wall
        case door
        case block(label: String)
        case marker(LayoutMarkerKind, label: String)
        case dropped
    }

    private static let blockLabels: [(prefix: String, label: String)] = [
        ("stairs.", "Stairs"),
        ("restroom.", "Restroom"),
        ("zone.stage_", "Stage"),
        ("zone.service_room", "Service Room"),
        ("zone.unlabeled_block", "Block")
    ]

    private static let droppedPrefixes = [
        "column.", "table.", "seats.", "safety.", "arrow.circulation", "info.desk",
        "zone.neighboring_unit", "zone.standing"
    ]

    private static let wallThicknessM: [String: Double] = [
        "wall.double": 0.2,
        "wall.medium": 0.15,
        "wall.thin": 0.1,
        "wall.thick": 0.3
    ]

    static func outcome(for symbolClass: String) -> Outcome? {
        if symbolClass == "arrow.entry" { return .marker(.spawn, label: "Entry") }
        if symbolClass == "arrow.exit" { return .marker(.exit, label: "Exit") }
        if symbolClass.hasPrefix("wall.") { return .wall }
        if symbolClass.hasPrefix("door.") || symbolClass.hasPrefix("gate.") { return .door }
        if let entry = blockLabels.first(where: { symbolClass.hasPrefix($0.prefix) }) {
            return .block(label: entry.label)
        }
        if droppedPrefixes.contains(where: { symbolClass.hasPrefix($0) }) { return .dropped }
        return nil
    }

    static func wallThicknessM(for symbolClass: String) -> Double? {
        wallThicknessM[symbolClass]
    }
}
