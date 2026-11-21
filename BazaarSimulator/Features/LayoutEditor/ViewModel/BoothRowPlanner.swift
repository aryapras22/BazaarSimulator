import Foundation
import simd

struct PlannedBooth: Equatable, Sendable {
    var id: UUID = UUID()
    var placement: Placement
    var openSides: OpenSides
    var isValid: Bool
}

struct BoothRowPlan: Equatable, Sendable {
    var booths: [PlannedBooth]
    var validCount: Int { booths.filter(\.isValid).count }
    var skippedCount: Int { booths.filter { !$0.isValid }.count }
}

enum BoothRowPlanner {
    static let defaultBoothSize = SIMD2<Double>(2.5, 2.5)
    static let defaultAisleWidthM = 2.0

    static func planRow(
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        boothSize: SIMD2<Double> = defaultBoothSize,
        in layout: Layout
    ) -> BoothRowPlan {
        let delta = end - start
        let len = simd_length(delta)
        let slotWidth = max(0.5, boothSize.x)
        let slotDepth = max(0.5, boothSize.y)
        guard len >= slotWidth else { return BoothRowPlan(booths: []) }

        let count = Int(floor(len / slotWidth))
        guard count > 0 else { return BoothRowPlan(booths: []) }

        let dir = delta / len
        let normal = SIMD2<Double>(-dir.y, dir.x)
        let rotationRad = atan2(dir.y, dir.x)
        let rotDeg = Int(round(rotationRad * 180.0 / .pi))

        var planned: [PlannedBooth] = []
        for index in 0..<count {
            let centerAlong = start + dir * ((Double(index) + 0.5) * slotWidth)
            let center = centerAlong + normal * (slotDepth / 2.0)
            let placement = Placement(
                center: center,
                sizeM: SIMD2<Double>(slotWidth, slotDepth),
                rotationRadians: rotationRad
            )
            let valid = isPlacementValid(placement, in: layout)
            planned.append(PlannedBooth(placement: placement, openSides: [], isValid: valid))
        }
        return BoothRowPlan(booths: planned)
    }

    static func planFill(
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        boothSize: SIMD2<Double> = defaultBoothSize,
        aisleWidthM: Double = defaultAisleWidthM,
        in layout: Layout
    ) -> BoothRowPlan {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        let width = maxX - minX
        let height = maxY - minY

        let slotWidth = max(0.5, boothSize.x)
        let slotDepth = max(0.5, boothSize.y)
        guard width >= slotWidth, height >= slotDepth else { return BoothRowPlan(booths: []) }

        let cols = Int(floor(width / slotWidth))
        guard cols > 0 else { return BoothRowPlan(booths: []) }

        let doubleRowDepth = 2.0 * slotDepth
        let pitch = doubleRowDepth + aisleWidthM
        var planned: [PlannedBooth] = []

        var currentY = minY
        while (currentY + slotDepth) <= maxY {
            for col in 0..<cols {
                let centerX = minX + (Double(col) + 0.5) * slotWidth
                let center = SIMD2<Double>(centerX, currentY + slotDepth / 2.0)
                planned.append(makePlannedBooth(
                    center: center,
                    size: SIMD2<Double>(slotWidth, slotDepth),
                    openSides: [],
                    layout: layout
                ))
            }
            if (currentY + doubleRowDepth) <= maxY {
                for col in 0..<cols {
                    let centerX = minX + (Double(col) + 0.5) * slotWidth
                    let center = SIMD2<Double>(centerX, currentY + slotDepth + slotDepth / 2.0)
                    planned.append(makePlannedBooth(
                        center: center,
                        size: SIMD2<Double>(slotWidth, slotDepth),
                        openSides: [],
                        layout: layout
                    ))
                }
            }
            currentY += pitch
        }

        return BoothRowPlan(booths: planned)
    }

    private static func makePlannedBooth(
        center: SIMD2<Double>,
        size: SIMD2<Double>,
        openSides: OpenSides,
        layout: Layout
    ) -> PlannedBooth {
        let placement = Placement(center: center, sizeM: size, rotationRadians: 0)
        let valid = isPlacementValid(placement, in: layout)
        return PlannedBooth(placement: placement, openSides: openSides, isValid: valid)
    }

    private static func isPlacementValid(_ placement: Placement, in layout: Layout) -> Bool {
        guard LayoutGeometry.isPlacementInsideWalkableFloor(placement, in: layout) else { return false }
        for object in layout.objects {
            if object.kind.blocksWalking || object.kind == .booth || object.kind == .door {
                if LayoutGeometry.intersects(object.placement, placement) {
                    return false
                }
            }
        }
        return true
    }
}
