import Foundation
import Testing
@testable import BazaarSimulator

@Suite("BestLayoutSummaryTests")
@MainActor
struct BestLayoutSummaryTests {
    @Test("The reasons read as one sentence")
    func sentenceJoinsReasons() {
        #expect(BestLayoutSummary.sentence(["fewer stuck spots", "less time stuck", "calmer crowds"])
            == "Fewer stuck spots, less time stuck and calmer crowds.")
        #expect(BestLayoutSummary.sentence(["calmer crowds"]) == "Calmer crowds.")
        #expect(BestLayoutSummary.sentence([]) == "Both layouts do about the same.")
    }

    private func viewModel(layoutCount: Int) async -> (DashboardViewModel, ProjectSession, UUID) {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")
        let layouts = [PreviewLayouts.annyeong(), PreviewLayouts.beyond(), PreviewLayouts.smallMarket()]
        session.setDraft(
            ProjectDraft(name: "Alpha", legend: Legend(), layouts: Array(layouts.prefix(layoutCount))),
            for: project.id
        )
        var parameters = EventParameters()
        parameters.totalVisitors = 20
        parameters.startMinutes = 10 * 60
        parameters.endMinutes = 10 * 60 + 15
        session.setParameters(parameters, for: project.id)
        session.runSimulations(for: project.id)
        while session.isSimulating(project.id) { try? await Task.sleep(for: .milliseconds(50)) }
        return (DashboardViewModel(projectID: project.id, session: session), session, project.id)
    }

    @Test("The page names a best layout with three headline numbers")
    func bestLayoutHasThreeStats() async {
        let (model, _, _) = await viewModel(layoutCount: 2)

        let summary = model.bestLayout
        #expect(summary?.stats.map(\.title) == ["Crowded Spots", "Time Stuck", "Crowd Level"])
        #expect(summary?.stats.allSatisfy { !$0.value.isEmpty && $0.other.hasPrefix("Layout") } == true)
    }

    @Test("A card can show any layout of the run, and picking the other card's layout swaps them")
    func selectingALayoutSwaps() async {
        let (model, _, _) = await viewModel(layoutCount: 3)
        #expect(model.layoutOptions.count == 3)
        #expect(model.selectedIndex(for: .one) == 0)
        #expect(model.selectedIndex(for: .two) == 1)

        model.select(2, for: .two)
        #expect(model.selectedIndex(for: .two) == 2)
        #expect(model.floorPlan(for: .two)?.name == model.layoutOptions[2].name)

        model.select(0, for: .two)
        #expect(model.selectedIndex(for: .two) == 0)
        #expect(model.selectedIndex(for: .one) == 2)
    }
}
