import Foundation
import simd

enum DoorLabelFormatter {
    private static let compassDirections = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

    static func displayTitle(for door: LayoutObject, in layout: Layout) -> String {
        let trimmed = door.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return "Door \(compassName(for: door, in: layout))"
    }

    static func compassName(for door: LayoutObject, in layout: Layout) -> String {
        let referencePolygon = layout.hall.isEmpty ? layout.lobby : layout.hall
        let bounds = LayoutGeometry.bounds(of: referencePolygon)
        let centerX = (bounds.minX + bounds.maxX) / 2.0
        let centerY = (bounds.minY + bounds.maxY) / 2.0

        let deltaX = door.placement.center.x - centerX
        let deltaY = door.placement.center.y - centerY
        let angle = atan2(deltaY, deltaX)
        let octant = Int(round(8.0 * angle / (2.0 * .pi) + 8.0)) % 8
        return compassDirections[octant]
    }
}
