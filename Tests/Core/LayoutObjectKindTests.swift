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
        #expect(kind.canBeAdded)
        #expect(kind.hasResizeHandles)
        #expect(kind.blocksWalking)
        #expect(kind.minimumDimensionM == 0.5)
        #expect(kind.isSelectable)
    }
}
