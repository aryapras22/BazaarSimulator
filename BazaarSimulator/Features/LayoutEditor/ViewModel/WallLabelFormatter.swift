import Foundation

/// Names a wall by the side of the hall it stands on, such as "Wall North", unless the user gave it a name.
enum WallLabelFormatter {
    static func displayTitle(for wall: LayoutObject, in layout: Layout) -> String {
        let trimmed = wall.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return "Wall \(sideName(for: wall, in: layout))"
    }

    /// North is the top of the plan. A wall that runs more across than up and down is a north or south wall.
    static func sideName(for wall: LayoutObject, in layout: Layout) -> String {
        let referencePolygon = layout.hall.isEmpty ? layout.lobby : layout.hall
        let bounds = LayoutGeometry.bounds(of: referencePolygon)
        let centerX = (bounds.minX + bounds.maxX) / 2.0
        let centerY = (bounds.minY + bounds.maxY) / 2.0
        let isAcross = abs(sin(wall.placement.rotationRadians)) < 0.5
        if isAcross {
            return wall.placement.center.y < centerY ? "North" : "South"
        }
        return wall.placement.center.x < centerX ? "West" : "East"
    }
}
