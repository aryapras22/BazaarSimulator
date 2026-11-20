import SwiftUI
import simd

enum DisabledObjectIndicator {
    static let mutedFill = Palette.canvasBoothFill.opacity(0.35)

    static func isDisabled(_ object: LayoutObject) -> Bool {
        if object.isDisabled {
            return true
        }
        if object.kind == .entertainment {
            return EntertainmentType.resolve(catalogID: object.catalogID, label: object.label) == .disabled
        }
        return false
    }

    static func displayLabel(for object: LayoutObject) -> String {
        let trimmed = object.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.caseInsensitiveCompare(LayoutObjectKind.entertainment.displayName) != .orderedSame,
              trimmed.caseInsensitiveCompare(LayoutObjectKind.booth.displayName) != .orderedSame,
              trimmed.caseInsensitiveCompare(EntertainmentType.disabled.displayName) != .orderedSame
        else {
            return EntertainmentType.disabled.displayName
        }
        return BoothLabelFormatter.display(trimmed)
    }

    static func drawOverlay(
        for placement: Placement,
        isSelected: Bool,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let corners = LayoutGeometry.corners(of: placement)
        guard corners.count == 4 else { return }
        let points = corners.map { corner -> CGPoint in
            let viewPoint = transform.toView(corner)
            return CGPoint(x: viewPoint.x, y: viewPoint.y)
        }

        var cross = Path()
        cross.move(to: points[0])
        cross.addLine(to: points[2])
        cross.move(to: points[1])
        cross.addLine(to: points[3])

        let strokeColor = isSelected ? Color.white.opacity(0.85) : Palette.canvasFlowLine
        context.stroke(cross, with: .color(strokeColor), lineWidth: 1.2)

        let outline = FloorRenderer.polygonPath(for: corners, transform: transform)
        context.stroke(
            outline,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
        )
    }
}
