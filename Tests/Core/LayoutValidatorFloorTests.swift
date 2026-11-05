import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutValidatorFloorTests {
    private let defaultHall: [SIMD2<Double>] = [
        SIMD2<Double>(0, 0),
        SIMD2<Double>(20, 0),
        SIMD2<Double>(20, 20),
        SIMD2<Double>(0, 20)
    ]

    @Test("A booth inside a floor object does not give outsideFloor warning")
    func boothInsideFloorObjectNoWarning() {
        let floor = LayoutObject(
            kind: .floor,
            label: "Floor",
            placement: Placement(center: SIMD2<Double>(25, 25), sizeM: SIMD2<Double>(6, 6))
        )
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(25, 25), sizeM: SIMD2<Double>(2, 2)),
            openSides: .all
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(40, 40),
            hall: defaultHall,
            objects: [floor, booth]
        )

        let issues = LayoutValidator.issues(in: layout)
        let outsideIssues = issues.filter { $0.kind == .outsideFloor }
        #expect(outsideIssues.isEmpty)
    }
}
