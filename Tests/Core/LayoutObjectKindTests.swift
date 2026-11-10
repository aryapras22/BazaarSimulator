import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutObjectKindTests {
    @Test("Blocked area kind facts")
    func blockedAreaKindFacts() {
        let kind = LayoutObjectKind.closedArea

        #expect(kind.displayName == "Restricted area")
        #expect(kind.isMovable)
        #expect(kind.isResizable)
        #expect(kind.isRotatable)
        #expect(kind.hasResizeHandles)
        #expect(kind.blocksWalking)
        #expect(kind.minimumDimensionM == 0.5)
        #expect(kind.isSelectable)
    }

    @Test("A table keeps its model size and turns by eighths, like seating, while booths turn by quarters")
    func tableFacts() {
        #expect(!LayoutObjectKind.table.isResizable)
        #expect(LayoutObjectKind.table.rotationStepDegrees == 45)
        #expect(LayoutObjectKind.seating.rotationStepDegrees == 45)
        #expect(LayoutObjectKind.booth.rotationStepDegrees == 90)
    }

    @Test("Booths, blocks, blocked areas and seating resize by handles, walls, doors and tables do not")
    func resizeHandleKinds() {
        #expect(LayoutObjectKind.allCases.filter(\.hasResizeHandles).map(\.rawValue).sorted()
            == [LayoutObjectKind.block, .booth, .closedArea, .seating].map(\.rawValue).sorted())
    }

    @Test("Decoding old project without floor succeeds")
    func decodingOldProjectWithoutFloorSucceeds() throws {
        let original = Layout(
            name: "Old Layout",
            sizeM: SIMD2(30, 30),
            hall: [SIMD2(0, 0), SIMD2(30, 0), SIMD2(30, 30), SIMD2(0, 30)],
            objects: [
                LayoutObject(
                    kind: .wall,
                    label: "Wall",
                    placement: Placement(center: SIMD2(10, 10), sizeM: SIMD2(4, 0.2))
                )
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Layout.self, from: data)
        #expect(decoded.name == "Old Layout")
        #expect(decoded.objects.count == 1)
        #expect(decoded.objects.first?.kind == .wall)
    }

    @Test("Every LayoutObjectKind belongs to exactly one layer", arguments: LayoutObjectKind.allCases)
    func eachKindBelongsToOneLayer(kind: LayoutObjectKind) {
        let layer = kind.layer
        switch kind {
        case .wall, .block, .door, .closedArea:
            #expect(layer == .structure)
        case .booth, .table, .seating:
            #expect(layer == .booths)
        }
    }
}
