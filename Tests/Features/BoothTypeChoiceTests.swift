import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct BoothTypeChoiceTests {
    @Test("Inspector booth category options are exactly Unassigned, Foods, and Goods regardless of legend")
    @MainActor
    func pickerBoothOptionsAreUnassignedFoodsGoods() {
        let session = ProjectSession()
        let project = session.createProject(named: "Night Market")
        let legend = Legend(entries: [
            LegendEntry(name: "FNB", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb),
            LegendEntry(name: "Fashion", color: LegendColor(red: 0, green: 1, blue: 0), type: .goods),
            LegendEntry(name: "Lifestyle & Hobbies", color: LegendColor(red: 0, green: 0, blue: 1), type: .goods)
        ])
        let layout = Layout(name: "Hall", sizeM: SIMD2(20, 20))
        session.setDraft(ProjectDraft(name: "Night Market", legend: legend, layouts: [layout]), for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)

        #expect(viewModel.categoryOptions.map(\.name) == ["Unassigned", "Foods", "Goods"])
        #expect(viewModel.categoryOptions.map(\.id) == [nil, .fnb, .goods])
    }

    @Test("Choosing Goods sets boothType without clearing categoryID, and Unassigned sets nil")
    func choosingGoodsSetsBoothType() {
        let legendEntryID = UUID()
        let original = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2(5, 5), sizeM: SIMD2(2, 2)),
            categoryID: legendEntryID,
            boothType: .fnb,
            openSides: [.bottom]
        )

        var draft = InspectorDraft(object: original)
        draft.choose(.booth(.goods))
        let updated = draft.applied(to: original)

        #expect(draft.categoryChoice == .booth(.goods))
        #expect(updated.boothType == .goods)
        #expect(updated.categoryID == legendEntryID)

        draft.choose(.booth(nil))
        let unassigned = draft.applied(to: updated)
        #expect(draft.categoryChoice == .booth(nil))
        #expect(unassigned.boothType == nil)
    }

    @Test("A legacy JSON booth without boothType loads its type from its legend entry")
    func legacyJSONBoothLoadsTypeFromLegend() throws {
        let foodID = UUID()
        let goodsID = UUID()
        let json = legacyDraftJSON(foodID: foodID, goodsID: goodsID)

        let draft = try JSONDecoder().decode(ProjectDraft.self, from: Data(json.utf8))
        let objects = try #require(draft.layouts.first?.objects)

        #expect(objects.first { $0.label == "F1" }?.boothType == .fnb)
        #expect(objects.first { $0.label == "G1" }?.boothType == .goods)
        #expect(objects.first { $0.label == "G2" }?.boothType == .goods)
    }

    private func legacyDraftJSON(foodID: UUID, goodsID: UUID) -> String {
        let foodBooth = """
        { "id": "\(UUID().uuidString)", "kind": "booth", "label": "F1", \
        "placement": { "center": [4.0, 4.0], "sizeM": [2.0, 2.0], "rotationRadians": 0.0 }, \
        "categoryID": "\(foodID.uuidString)", "openSides": 4, "reviewState": "confirmed" }
        """
        let goodsBooth = """
        { "id": "\(UUID().uuidString)", "kind": "booth", "label": "G1", \
        "placement": { "center": [8.0, 4.0], "sizeM": [2.0, 2.0], "rotationRadians": 0.0 }, \
        "categoryID": "\(goodsID.uuidString)", "openSides": 4, "reviewState": "confirmed" }
        """
        let overrideBooth = """
        { "id": "\(UUID().uuidString)", "kind": "booth", "label": "G2", \
        "placement": { "center": [12.0, 4.0], "sizeM": [2.0, 2.0], "rotationRadians": 0.0 }, \
        "categoryID": "\(foodID.uuidString)", "boothType": "goods", "openSides": 4, "reviewState": "confirmed" }
        """
        return """
        {
            "name": "Legacy Market",
            "legend": {
                "entries": [
                    { "id": "\(foodID.uuidString)", "name": "FNB", \
        "color": { "red": 1.0, "green": 0.0, "blue": 0.0 }, "type": "fnb" },
                    { "id": "\(goodsID.uuidString)", "name": "Fashion", \
        "color": { "red": 0.0, "green": 1.0, "blue": 0.0 }, "type": "goods" }
                ]
            },
            "layouts": [{
                "id": "\(UUID().uuidString)", "name": "Plan 1", "sizeM": [20.0, 20.0],
                "hall": [], "lobby": [], "objects": [\(foodBooth), \(goodsBooth), \(overrideBooth)],
                "markers": [], "zones": [], "source": { "name": "Plan 1", "sheet": "", "note": "" }
            }]
        }
        """
    }

    @Test("The simulation treats a booth with boothType fnb as food regardless of legend")
    @MainActor
    func simulationUsesBoothTypeRegardlessOfLegend() {
        let foodLegend = LegendEntry(name: "FNB", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        let goodsLegend = LegendEntry(name: "Fashion", color: LegendColor(red: 0, green: 1, blue: 0), type: .goods)

        let foodBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2(6, 6), sizeM: SIMD2(2, 2)),
            categoryID: goodsLegend.id,
            boothType: .fnb
        )
        let goodsBooth = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2(10, 6), sizeM: SIMD2(2, 2)),
            categoryID: foodLegend.id,
            boothType: .goods
        )
        let unassignedBooth = LayoutObject(
            kind: .booth,
            label: "B3",
            placement: Placement(center: SIMD2(14, 6), sizeM: SIMD2(2, 2)),
            categoryID: foodLegend.id,
            boothType: nil
        )
        let layout = Layout(
            name: "Hall",
            sizeM: SIMD2(20, 20),
            objects: [foodBooth, goodsBooth, unassignedBooth],
            markers: [
                LayoutMarker(kind: .spawn, label: "In", position: SIMD2(2, 2)),
                LayoutMarker(kind: .exit, label: "Out", position: SIMD2(18, 2))
            ]
        )

        let world = CrowdWorld(layout: layout, legend: Legend(entries: [foodLegend, goodsLegend]))

        #expect(world.booths[0].isFood)
        #expect(!world.booths[1].isFood)
        #expect(!world.booths[2].isFood)
    }
}
