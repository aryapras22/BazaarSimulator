import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct DoorFlowAdvisorTests {
    private func makeDoor(
        label: String,
        direction: DoorDirection,
        width: Double = 2.0,
        connection: DoorConnection = .hallToLobby
    ) -> LayoutObject {
        LayoutObject(
            kind: .door,
            label: label,
            placement: Placement(center: .zero, sizeM: SIMD2<Double>(width, 0.4)),
            doorFlow: DoorFlow(direction: direction, connection: connection)
        )
    }

    @Test("Rule 1 advises making the door an entrance when no door allows entry")
    func ruleOneNoEntry() {
        let doorA = makeDoor(label: "Door A", direction: .exit)
        let doorB = makeDoor(label: "Door B", direction: .disabled)
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [doorA, doorB])

        let advice = DoorFlowAdvisor.advice(for: doorA, in: layout)

        #expect(advice == DoorAdviceText.noEntry(doorLabel: "Door A"))
    }

    @Test("Rule 2 advises making the door an exit when no door allows exit")
    func ruleTwoNoExit() {
        let doorA = makeDoor(label: "Door A", direction: .entrance)
        let doorB = makeDoor(label: "Door B", direction: .disabled)
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [doorA, doorB])

        let advice = DoorFlowAdvisor.advice(for: doorA, in: layout)

        #expect(advice == DoorAdviceText.noExit(doorLabel: "Door A"))
    }

    @Test("Rule 3 advises making the widest disabled door Both")
    func ruleThreeWidestDisabled() {
        let wideDisabled = makeDoor(label: "Door A", direction: .disabled, width: 4.0)
        let narrowBoth = makeDoor(label: "Door B", direction: .both, width: 2.0)
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [wideDisabled, narrowBoth])

        let advice = DoorFlowAdvisor.advice(for: wideDisabled, in: layout)

        #expect(advice == DoorAdviceText.widestDisabled(doorLabel: "Door A"))
    }

    @Test("Rule 4 names the exit-only door and the selected Both door when no entrance-only door exists")
    func ruleFourPairWithExitOnly() {
        let doorNW = makeDoor(label: "Door NW", direction: .both)
        let doorNE = makeDoor(label: "Door NE", direction: .exit)
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [doorNW, doorNE])

        let advice = DoorFlowAdvisor.advice(for: doorNW, in: layout)

        #expect(
            advice == DoorAdviceText.pairWithExitOnly(
                otherDoorLabel: "Door NE",
                selectedDoorLabel: "Door NW"
            )
        )
    }

    @Test("Returns no advice when entrances and exits are well configured")
    func noAdviceWhenConfigured() {
        let doorNW = makeDoor(label: "Door NW", direction: .entrance)
        let doorNE = makeDoor(label: "Door NE", direction: .exit)
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [doorNW, doorNE])

        #expect(DoorFlowAdvisor.advice(for: doorNW, in: layout) == nil)
        #expect(DoorFlowAdvisor.advice(for: doorNE, in: layout) == nil)
    }
}
