import SwiftUI

/// The layout drawn as a floor plan: floor, booths, tables, stage, walls, and doors.
/// Everything is placed through `plan`, so overlays that use the same frame line up with it.
struct LayoutPlanCanvas: View, Equatable {
    let layout: Layout
    let plan: PlanFrame

    var body: some View {
        Canvas { context, size in
            let scale = CGSize(width: size.width / plan.size.x, height: size.height / plan.size.y)
            func point(_ meters: SIMD2<Double>) -> CGPoint {
                CGPoint(x: (meters.x - plan.origin.x) * scale.width, y: (meters.y - plan.origin.y) * scale.height)
            }
            func path(_ corners: [SIMD2<Double>]) -> Path {
                var path = Path()
                guard let first = corners.first else { return path }
                path.move(to: point(first))
                corners.dropFirst().forEach { path.addLine(to: point($0)) }
                path.closeSubpath()
                return path
            }

            context.fill(path(layout.hall), with: .color(Style.floor))
            context.fill(path(layout.lobby), with: .color(Style.lobby))

            for kind in Style.drawOrder {
                for object in layout.objects where object.kind == kind {
                    let shape = path(LayoutGeometry.corners(of: object.placement))
                    context.fill(shape, with: .color(Style.fill(for: object)))
                    if let outline = Style.outline(for: kind) {
                        context.stroke(shape, with: .color(outline), lineWidth: 1)
                    }
                    if kind == .entertainment {
                        let label = Text(object.label.uppercased()).font(.system(size: max(size.width / 60, 8), weight: .bold))
                        context.draw(label, at: point(object.placement.center))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private enum Style {
        static let floor = Color(hex: 0xF4F6F9)
        static let lobby = Color(hex: 0xE8ECF2)
        static let drawOrder: [LayoutObjectKind] = [
            .closedArea, .seating, .table, .booth, .entertainment, .block, .wall, .door
        ]

        static func fill(for object: LayoutObject) -> Color {
            switch object.kind {
            case .booth: object.isDisabled ? Color(hex: 0xD3D6DB) : Color(hex: 0xE4DBC8)
            case .table: Color(hex: 0xC3C9D2)
            case .entertainment: Color(hex: 0x9AA2AF)
            case .wall, .block: Color(hex: 0x5E6775)
            case .closedArea: Color(hex: 0xC9CED6).opacity(0.85)
            case .seating: Color(hex: 0xDDE2E9)
            case .door:
                object.doorFlow?.direction == .entrance ? Color(hex: 0x3FA66B) : Color(hex: 0xE5483B)
            }
        }

        static func outline(for kind: LayoutObjectKind) -> Color? {
            switch kind {
            case .booth, .table, .entertainment: Color(hex: 0x9C9484).opacity(0.7)
            default: nil
            }
        }
    }
}
