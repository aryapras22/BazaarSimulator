import Testing
@testable import BazaarSimulator

@Suite
struct ImportedDoorFlowTests {
    @Test("A door under half as wide as the widest arrives closed, the others open both ways")
    func sideDoorsArriveClosed() {
        let plan = DetectedPlan(items: [
            DetectedItem(cls: "door", box: [0, 0, 100, 20]),
            DetectedItem(cls: "door", box: [0, 300, 60, 20]),
            DetectedItem(cls: "door", box: [0, 600, 30, 20])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: Legend(), pixelsPerMetre: 10, name: "Plan")

        let directions = layout.objects.filter { $0.kind == .door }.map { $0.doorFlow?.direction }
        #expect(directions == [.both, .both, .disabled])
    }

    @Test("A gate becomes an open door along its long side, though no wall holds it")
    func gateNeedsNoWall() throws {
        let plan = DetectedPlan(items: [
            DetectedItem(cls: "Booth A", box: [0, 0, 50, 50], id: "A1"),
            DetectedItem(cls: "gate", box: [200, 100, 20, 60])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: Legend(), pixelsPerMetre: 20, name: "Plan")

        let gate = try #require(layout.objects.first { $0.kind == .door })
        #expect(gate.placement.sizeM.x == 3)
        #expect(gate.placement.rotationRadians == .pi / 2)
        #expect(gate.doorFlow?.direction == .both)
    }
}
