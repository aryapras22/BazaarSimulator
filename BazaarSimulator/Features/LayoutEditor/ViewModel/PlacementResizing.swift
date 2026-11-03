import SwiftUI
import simd

enum ResizeHandle: CaseIterable, Hashable, Sendable {
    case topLeading, top, topTrailing
    case leading, trailing
    case bottomLeading, bottom, bottomTrailing

    var pointerPosition: FrameResizePosition {
        switch self {
        case .topLeading: return .topLeading
        case .top: return .top
        case .topTrailing: return .topTrailing
        case .leading: return .leading
        case .trailing: return .trailing
        case .bottomLeading: return .bottomLeading
        case .bottom: return .bottom
        case .bottomTrailing: return .bottomTrailing
        }
    }

    func localPosition(for sizeM: SIMD2<Double>) -> SIMD2<Double> {
        let halfW = sizeM.x / 2.0
        let halfH = sizeM.y / 2.0
        switch self {
        case .topLeading: return SIMD2<Double>(-halfW, -halfH)
        case .top: return SIMD2<Double>(0, -halfH)
        case .topTrailing: return SIMD2<Double>(halfW, -halfH)
        case .leading: return SIMD2<Double>(-halfW, 0)
        case .trailing: return SIMD2<Double>(halfW, 0)
        case .bottomLeading: return SIMD2<Double>(-halfW, halfH)
        case .bottom: return SIMD2<Double>(0, halfH)
        case .bottomTrailing: return SIMD2<Double>(halfW, halfH)
        }
    }
}

enum PlacementResizing {
    static let minimumDimensionM = 0.5
    static let handleHitRadiusPt: CGFloat = 8
    static let handleVisualRadiusPt: CGFloat = 4

    static func handlePosition(for handle: ResizeHandle, in placement: Placement) -> SIMD2<Double> {
        LayoutGeometry.toWorld(local: handle.localPosition(for: placement.sizeM), in: placement)
    }

    static func hitTest(
        placement: Placement,
        pointerWorld: SIMD2<Double>,
        pointsPerMetre: Double
    ) -> ResizeHandle? {
        let hitRadiusM = Double(handleHitRadiusPt) / pointsPerMetre
        var closestHandle: ResizeHandle?
        var minDistance = Double.infinity

        for handle in ResizeHandle.allCases {
            let handleWorld = handlePosition(for: handle, in: placement)
            let distance = hypot(pointerWorld.x - handleWorld.x, pointerWorld.y - handleWorld.y)
            if distance <= hitRadiusM && distance < minDistance {
                minDistance = distance
                closestHandle = handle
            }
        }
        return closestHandle
    }

    static func resized(
        placement: Placement,
        handle: ResizeHandle,
        deltaWorld: SIMD2<Double>,
        snapCellM: Double = 0.25,
        snapped: Bool = true
    ) -> Placement {
        let cosA = cos(-placement.rotationRadians)
        let sinA = sin(-placement.rotationRadians)
        let deltaLocal = SIMD2<Double>(
            deltaWorld.x * cosA - deltaWorld.y * sinA,
            deltaWorld.x * sinA + deltaWorld.y * cosA
        )

        let initialW = placement.sizeM.x
        let initialH = placement.sizeM.y

        func snap(_ val: Double) -> Double {
            snapped ? max(minimumDimensionM, (val / snapCellM).rounded() * snapCellM) : max(minimumDimensionM, val)
        }

        var finalW = initialW
        var localCenterX = 0.0
        switch handle {
        case .topLeading, .leading, .bottomLeading:
            finalW = snap(initialW - deltaLocal.x)
            localCenterX = -(finalW - initialW) / 2.0
        case .topTrailing, .trailing, .bottomTrailing:
            finalW = snap(initialW + deltaLocal.x)
            localCenterX = (finalW - initialW) / 2.0
        case .top, .bottom:
            break
        }

        var finalH = initialH
        var localCenterY = 0.0
        switch handle {
        case .topLeading, .top, .topTrailing:
            finalH = snap(initialH - deltaLocal.y)
            localCenterY = -(finalH - initialH) / 2.0
        case .bottomLeading, .bottom, .bottomTrailing:
            finalH = snap(initialH + deltaLocal.y)
            localCenterY = (finalH - initialH) / 2.0
        case .leading, .trailing:
            break
        }

        let newCenterLocal = SIMD2<Double>(localCenterX, localCenterY)
        let newCenterWorld = LayoutGeometry.toWorld(local: newCenterLocal, in: placement)
        return Placement(
            center: newCenterWorld,
            sizeM: SIMD2<Double>(finalW, finalH),
            rotationRadians: placement.rotationRadians
        )
    }
}
