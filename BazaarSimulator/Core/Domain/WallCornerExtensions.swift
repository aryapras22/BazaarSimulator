import Foundation
import simd

struct WallCornerExtensions: Sendable {
    struct Extension: Sendable {
        var start: Double = 0.0
        var end: Double = 0.0
    }

    private let extensionsByWallID: [UUID: Extension]

    init(layout: Layout, graph: WallGraph? = nil) {
        let wallGraph = graph ?? WallGraph(layout: layout)
        var map: [UUID: Extension] = [:]
        for node in wallGraph.nodes {
            guard node.incidents.count == 2,
                  node.incidents.allSatisfy({ $0.end != .body }) else {
                continue
            }
            let incA = node.incidents[0]
            let incB = node.incidents[1]
            guard let wallA = layout.objects.first(where: { $0.id == incA.wallID }),
                  let wallB = layout.objects.first(where: { $0.id == incB.wallID }),
                  wallA.kind == .wall, wallB.kind == .wall else {
                continue
            }
            let extA = wallB.placement.sizeM.y / 2.0
            let extB = wallA.placement.sizeM.y / 2.0

            var entryA = map[wallA.id, default: Extension()]
            if incA.end == .start { entryA.start = extA } else { entryA.end = extA }
            map[wallA.id] = entryA

            var entryB = map[wallB.id, default: Extension()]
            if incB.end == .start { entryB.start = extB } else { entryB.end = extB }
            map[wallB.id] = entryB
        }
        self.extensionsByWallID = map
    }

    func extensions(for wallID: UUID) -> (start: Double, end: Double) {
        guard let ext = extensionsByWallID[wallID] else { return (0.0, 0.0) }
        return (ext.start, ext.end)
    }

    static func extendedCorners(
        for wall: LayoutObject,
        extensions: (start: Double, end: Double)
    ) -> [SIMD2<Double>] {
        let halfL = wall.placement.sizeM.x / 2.0
        let halfT = wall.placement.sizeM.y / 2.0
        let extStart = extensions.start
        let extEnd = extensions.end
        let localCorners: [SIMD2<Double>] = [
            SIMD2<Double>(-halfL - extStart, -halfT),
            SIMD2<Double>(halfL + extEnd, -halfT),
            SIMD2<Double>(halfL + extEnd, halfT),
            SIMD2<Double>(-halfL - extStart, halfT)
        ]
        return localCorners.map { LayoutGeometry.toWorld(local: $0, in: wall.placement) }
    }
}
