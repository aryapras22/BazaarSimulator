import Foundation
import simd

enum BoothShape {
    static let panelHeightM = 2.4
    static let counterHeightM = 1.0
    static let fasciaDepthM = 0.4
    static let panelThicknessM = 0.05

    /// Panels on closed sides, counters on open sides, a fascia over each open side.
    /// Local frame, before rotation.
    static func primitives(size: SIMD2<Double>, openSides: OpenSides) -> [ShapePrimitive] {
        let thickness = min(panelThicknessM, min(size.x, size.y) * 0.25)
        let counterDepth = min(0.5, min(size.x, size.y) * 0.4)
        var result: [ShapePrimitive] = []

        for side in OpenSides.ordered {
            if openSides.contains(side) {
                result.append(contentsOf: openSidePrimitives(
                    side: side, size: size,
                    thickness: thickness, counterDepth: counterDepth
                ))
            } else {
                result.append(closedSidePrimitive(
                    side: side, size: size, thickness: thickness
                ))
            }
        }

        return result
    }

    private static func openSidePrimitives(
        side: OpenSides,
        size: SIMD2<Double>,
        thickness: Double,
        counterDepth: Double
    ) -> [ShapePrimitive] {
        let halfW = size.x / 2.0
        let halfD = size.y / 2.0
        let counterCenter: SIMD3<Double>
        let counterSize: SIMD3<Double>
        let fasciaCenter: SIMD3<Double>
        let fasciaSize: SIMD3<Double>

        switch side {
        case .top:
            counterCenter = SIMD3(0, counterHeightM / 2.0, -halfD + counterDepth / 2.0)
            counterSize = SIMD3(size.x, counterHeightM, counterDepth)
            fasciaCenter = SIMD3(0, panelHeightM - fasciaDepthM / 2.0, -halfD + thickness / 2.0)
            fasciaSize = SIMD3(size.x, fasciaDepthM, thickness)
        case .bottom:
            counterCenter = SIMD3(0, counterHeightM / 2.0, halfD - counterDepth / 2.0)
            counterSize = SIMD3(size.x, counterHeightM, counterDepth)
            fasciaCenter = SIMD3(0, panelHeightM - fasciaDepthM / 2.0, halfD - thickness / 2.0)
            fasciaSize = SIMD3(size.x, fasciaDepthM, thickness)
        case .left:
            counterCenter = SIMD3(-halfW + counterDepth / 2.0, counterHeightM / 2.0, 0)
            counterSize = SIMD3(counterDepth, counterHeightM, size.y)
            fasciaCenter = SIMD3(-halfW + thickness / 2.0, panelHeightM - fasciaDepthM / 2.0, 0)
            fasciaSize = SIMD3(thickness, fasciaDepthM, size.y)
        default: // .right
            counterCenter = SIMD3(halfW - counterDepth / 2.0, counterHeightM / 2.0, 0)
            counterSize = SIMD3(counterDepth, counterHeightM, size.y)
            fasciaCenter = SIMD3(halfW - thickness / 2.0, panelHeightM - fasciaDepthM / 2.0, 0)
            fasciaSize = SIMD3(thickness, fasciaDepthM, size.y)
        }

        return [
            .box(center: counterCenter, size: counterSize, yaw: 0, role: .counter),
            .box(center: fasciaCenter, size: fasciaSize, yaw: 0, role: .fascia)
        ]
    }

    private static func closedSidePrimitive(
        side: OpenSides,
        size: SIMD2<Double>,
        thickness: Double
    ) -> ShapePrimitive {
        let halfW = size.x / 2.0
        let halfD = size.y / 2.0
        let center: SIMD3<Double>
        let panelSize: SIMD3<Double>

        switch side {
        case .top:
            center = SIMD3(0, panelHeightM / 2.0, -halfD + thickness / 2.0)
            panelSize = SIMD3(size.x, panelHeightM, thickness)
        case .bottom:
            center = SIMD3(0, panelHeightM / 2.0, halfD - thickness / 2.0)
            panelSize = SIMD3(size.x, panelHeightM, thickness)
        case .left:
            center = SIMD3(-halfW + thickness / 2.0, panelHeightM / 2.0, 0)
            panelSize = SIMD3(thickness, panelHeightM, size.y)
        default: // .right
            center = SIMD3(halfW - thickness / 2.0, panelHeightM / 2.0, 0)
            panelSize = SIMD3(thickness, panelHeightM, size.y)
        }

        return .box(center: center, size: panelSize, yaw: 0, role: .panel)
    }
}
