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

    @Test("Door label text includes entrance, exit, both, or disabled")
    func doorLabelTextIncludesDirection() {
        let placement = Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 0.4))
        let cases: [(DoorDirection, String)] = [
            (.entrance, "Door A · Entrance"),
            (.exit, "Door A · Exit"),
            (.both, "Door A · Both"),
            (.disabled, "Door A · Disabled")
        ]

        for (direction, expected) in cases {
            let door = LayoutObject(
                kind: .door,
                label: "Door A",
                placement: placement,
                doorFlow: DoorFlow(direction: direction)
            )
            #expect(DoorRenderer.labelText(for: door) == expected)
        }

        let unlabeledDoor = LayoutObject(kind: .door, label: "", placement: placement)
        #expect(DoorRenderer.labelText(for: unlabeledDoor) == "Door · Both")
    }
}
