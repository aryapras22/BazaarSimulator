import SwiftUI

/// The layout drawn as a floor plan: floor, booths, tables, stage, walls, and doors.
/// Everything is placed through `plan`, so overlays that use the same frame line up with it.
struct LayoutPlanCanvas: View, Equatable {
    enum ColorMode: Equatable {
        case neutral
        case simulation
    }

    let layout: Layout
    let plan: PlanFrame
    /// With a legend, a booth is filled with the color of its category. Without one, every booth is the same beige.
    var legend: Legend?
    var colorMode: ColorMode = .neutral

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

            let hallShape = layout.hall.count >= 3
                ? path(layout.hall)
                : (colorMode == .simulation
                    ? path([.zero, SIMD2(layout.sizeM.x, 0), layout.sizeM, SIMD2(0, layout.sizeM.y)])
                    : Path())
            if !hallShape.isEmpty {
                context.fill(hallShape, with: .color(Style.floor(for: colorMode)))
                if let surfaceOutline = Style.surfaceOutline(for: colorMode) {
                    context.stroke(hallShape, with: .color(surfaceOutline), lineWidth: 1)
                }
            }

            let lobbyShape = path(layout.lobby)
            if !lobbyShape.isEmpty {
                context.fill(lobbyShape, with: .color(Style.lobby(for: colorMode)))
                if let surfaceOutline = Style.surfaceOutline(for: colorMode) {
                    context.stroke(lobbyShape, with: .color(surfaceOutline), lineWidth: 1)
                }
            }

            for kind in Style.drawOrder {
                for object in layout.objects where object.kind == kind {
                    let shape = path(LayoutGeometry.corners(of: object.placement))
                    context.fill(shape, with: .color(Style.fill(for: object, legend: legend, colorMode: colorMode)))
                    if let outline = Style.outline(for: kind, colorMode: colorMode) {
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
        static let drawOrder: [LayoutObjectKind] = [
            .closedArea, .seating, .table, .booth, .entertainment, .block, .wall, .door
        ]

        static func floor(for colorMode: ColorMode) -> Color {
            switch colorMode {
            case .neutral: Color(hex: 0xF4F6F9)
            case .simulation: TenantColors.hallFloorColor
            }
        }

        static func lobby(for colorMode: ColorMode) -> Color {
            switch colorMode {
            case .neutral: Color(hex: 0xE8ECF2)
            case .simulation: TenantColors.lobbyFloorColor
            }
        }

        static func surfaceOutline(for colorMode: ColorMode) -> Color? {
            switch colorMode {
            case .neutral: nil
            case .simulation: TenantColors.outlineColor
            }
        }

        static func fill(for object: LayoutObject, legend: Legend?, colorMode: ColorMode) -> Color {
            if colorMode == .simulation {
                return TenantColors.objectColor(for: object, legend: legend ?? Legend())
            }
            switch object.kind {
            case .booth: return boothFill(for: object, legend: legend)
            case .table: return Color(hex: 0xC3C9D2)
            case .entertainment: return Color(hex: 0x9AA2AF)
            case .wall, .block: return Color(hex: 0x5E6775)
            case .closedArea: return Color(hex: 0xC9CED6).opacity(0.85)
            case .seating: return Color(hex: 0xDDE2E9)
            case .door:
                return object.doorFlow?.direction == .entrance ? Color(hex: 0x3FA66B) : Color(hex: 0xE5483B)
            }
        }

        /// A disabled booth is gray. Otherwise it takes its category's color from the legend, and the plain beige when
        /// it has no category or there is no legend.
        private static func boothFill(for object: LayoutObject, legend: Legend?) -> Color {
            if object.isDisabled { return Color(hex: 0xD3D6DB) }
            guard let categoryID = object.categoryID,
                  let entry = legend?.entries.first(where: { $0.id == categoryID })
            else { return Color(hex: 0xE4DBC8) }
            return Color(.sRGB, red: entry.color.red, green: entry.color.green, blue: entry.color.blue, opacity: 0.9)
        }

        static func outline(for kind: LayoutObjectKind, colorMode: ColorMode) -> Color? {
            if colorMode == .simulation {
                return TenantColors.outlineColor
            }
            switch kind {
            case .booth, .table, .entertainment: return Color(hex: 0x9C9484).opacity(0.7)
            default: return nil
            }
        }
    }
}
