import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct AnalysisServiceTests {
    private let focus = TimeRange(startMinute: 11 * 60, endMinute: 11 * 60 + 10)

    private func analyses(
        _ service: AnalysisService,
        layouts: [Layout],
        parameters: EventParameters = TestLayouts.parameters
    ) async -> [LayoutAnalysis] {
        await service.analyses(for: layouts, parameters: parameters, visitorTypes: TestLayouts.visitorTypes, focus: focus)
    }

    @Test("One analysis per layout, in order")
    func onePerLayout() async {
        let first = TestLayouts.hall(booths: 3)
        let second = TestLayouts.hall(booths: 5)
        let results = await analyses(AnalysisService(), layouts: [first, second])
        #expect(results.map(\.layoutID) == [first.id, second.id])
    }

    @Test("The same request gives the same result again")
    func cached() async {
        let service = AnalysisService()
        let layout = TestLayouts.hall()
        let first = await analyses(service, layouts: [layout])
        let second = await analyses(service, layouts: [layout])
        #expect(first == second)
    }

    @Test("Changing the parameters runs the simulation again")
    func parametersInvalidate() async {
        let service = AnalysisService()
        let layout = TestLayouts.hall()
        var other = TestLayouts.parameters
        other.totalVisitors = 900
        let first = await analyses(service, layouts: [layout])
        let second = await analyses(service, layouts: [layout], parameters: other)
        #expect(first != second)
        #expect(second.first?.totalPeople == 900)
    }

    @Test("Changing the layout runs the simulation again")
    func layoutInvalidates() async {
        let service = AnalysisService()
        var layout = TestLayouts.hall()
        let first = await analyses(service, layouts: [layout])
        layout.objects.removeAll { $0.kind == .booth }
        let second = await analyses(service, layouts: [layout])
        #expect(first != second)
    }
}
