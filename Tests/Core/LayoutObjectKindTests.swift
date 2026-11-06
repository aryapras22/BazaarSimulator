import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutObjectKindTests {
    @Test("Blocked area kind facts")
    func blockedAreaKindFacts() {
        let kind = LayoutObjectKind.closedArea

        #expect(kind.displayName == "Blocked area")
        #expect(kind.isMovable)
        #expect(kind.isResizable)
        #expect(kind.isRotatable)
        #expect(kind.hasResizeHandles)
        #expect(kind.blocksWalking)
        #expect(kind.minimumDimensionM == 0.5)
        #expect(kind.isSelectable)
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
        case .booth:
            #expect(layer == .booths)
        }
    }
}
