import Foundation
import simd

/// Pushes imported tables apart until nobody's chairs touch another table or its chairs, so every seat can be used.
/// The extractor places tables where the plan draws them, and the drawing often packs them closer than a chair needs.
/// A table never moves more than `maxShiftM`, so the layout stays the plan's layout.
enum TableSpacing {
    static let clearanceM = 0.1
    static let maxShiftM = 1.0
    private static let stepM = 0.05
    private static let maxRounds = 400
    /// Two tables further apart than this cannot reach each other with chairs on.
    private static let neighbourReachM = 4.0

    static func apply(to objects: [LayoutObject]) -> [LayoutObject] {
        let tableIndices = objects.indices.filter { objects[$0].kind == .table }
        guard tableIndices.count > 1 else { return objects }
        let origins = tableIndices.map { objects[$0].placement.center }
        var tables = tableIndices.map { objects[$0] }

        for _ in 0..<maxRounds {
            var pushes = [SIMD2<Double>](repeating: .zero, count: tables.count)
            var touching = false
            for first in tables.indices {
                for second in tables.indices where second > first && collide(tables[first], tables[second]) {
                    touching = true
                    let apart = tables[second].placement.center - tables[first].placement.center
                    let direction = simd_length(apart) > 1e-9 ? simd_normalize(apart) : SIMD2(1, 0)
                    pushes[first] -= direction * stepM / 2
                    pushes[second] += direction * stepM / 2
                }
            }
            guard touching else { break }
            for index in tables.indices {
                var moved = tables[index].placement.center + pushes[index]
                let shift = moved - origins[index]
                if simd_length(shift) > maxShiftM { moved = origins[index] + simd_normalize(shift) * maxShiftM }
                tables[index].placement.center = moved
            }
        }

        var result = objects
        for (position, index) in tableIndices.enumerated() { result[index] = tables[position] }
        return result
    }

    private static func collide(_ first: LayoutObject, _ second: LayoutObject) -> Bool {
        guard simd_length(first.placement.center - second.placement.center) < neighbourReachM else { return false }
        let firstPieces = pieces(of: first)
        let secondPieces = pieces(of: second)
        return firstPieces.contains { piece in secondPieces.contains { LayoutGeometry.intersects(piece, $0) } }
    }

    /// The table and its chairs, each grown by half the clearance so two pieces closer than the clearance overlap.
    private static func pieces(of table: LayoutObject) -> [Placement] {
        ([table.placement] + FurnitureModels.chairs(of: table)).map { piece in
            Placement(
                center: piece.center,
                sizeM: piece.sizeM + SIMD2(repeating: clearanceM),
                rotationRadians: piece.rotationRadians
            )
        }
    }
}
