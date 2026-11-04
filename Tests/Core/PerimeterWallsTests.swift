import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct PerimeterWallsTests {
    @Test("A hall edge with one door gives two spans and a lintel")
    func hallEdgeWithOneDoor() {
        let hall = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(10, 0),
            SIMD2<Double>(10, 10),
            SIMD2<Double>(0, 10)
        ]
        let door = LayoutObject(
            kind: .door,
            label: "D1",
            placement: Placement(center: SIMD2<Double>(5, 0), sizeM: SIMD2<Double>(2, 0.2))
        )
        let layout = Layout(
            id: UUID(),
            name: "Test",
            sizeM: SIMD2<Double>(10, 10),
            hall: hall,
            lobby: [],
            objects: [door],
            markers: [],
            zones: []
        )

        let spans = PerimeterWalls.spans(for: layout)

        // Find spans on the top edge (y == 0, x between 0 and 10)
        let topSpans = spans.filter { abs($0.start.y) < 1e-3 && abs($0.end.y) < 1e-3 }

        let wallSpans = topSpans.filter { $0.bottom == 0.0 }
        let lintelSpans = topSpans.filter { abs($0.bottom - PerimeterWalls.lintelM) < 1e-3 }

        #expect(wallSpans.count == 2)
        #expect(lintelSpans.count == 1)

        let lintel = lintelSpans[0]
        #expect(abs(lintel.start.x - 4.0) < 1e-3)
        #expect(abs(lintel.end.x - 6.0) < 1e-3)
        #expect(lintel.top == PerimeterWalls.heightM)
    }

    @Test("A door at a corner clips to the edge")
    func doorAtCornerClips() {
        let hall = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(10, 0),
            SIMD2<Double>(10, 10),
            SIMD2<Double>(0, 10)
        ]
        // Door centered at (0, 0) with width 2
        let door = LayoutObject(
            kind: .door,
            label: "D1",
            placement: Placement(center: SIMD2<Double>(0, 0), sizeM: SIMD2<Double>(2, 0.2))
        )
        let layout = Layout(
            id: UUID(),
            name: "Corner Door",
            sizeM: SIMD2<Double>(10, 10),
            hall: hall,
            lobby: [],
            objects: [door],
            markers: [],
            zones: []
        )

        let spans = PerimeterWalls.spans(for: layout)
        let topSpans = spans.filter { abs($0.start.y) < 1e-3 && abs($0.end.y) < 1e-3 }

        let wallSpans = topSpans.filter { $0.bottom == 0.0 }
        let lintelSpans = topSpans.filter { abs($0.bottom - PerimeterWalls.lintelM) < 1e-3 }

        #expect(lintelSpans.count == 1)
        #expect(wallSpans.count == 1)

        let lintel = lintelSpans[0]
        #expect(abs(lintel.start.x - 0.0) < 1e-3)
        #expect(abs(lintel.end.x - 1.0) < 1e-3)
    }
}
