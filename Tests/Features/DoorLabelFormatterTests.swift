import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct DoorLabelFormatterTests {
    @Test("A door at the top left of the hall is NW")
    func topLeftDoorIsNW() {
        let hall: [SIMD2<Double>] = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(20, 0),
            SIMD2<Double>(20, 20),
            SIMD2<Double>(0, 20)
        ]
        let door = LayoutObject(
            kind: .door,
            label: "",
            placement: Placement(center: SIMD2<Double>(2, 2), sizeM: SIMD2<Double>(2, 0.4))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), hall: hall, objects: [door])

        #expect(DoorLabelFormatter.compassName(for: door, in: layout) == "NW")
        #expect(DoorLabelFormatter.displayTitle(for: door, in: layout) == "Door NW")
    }
}
