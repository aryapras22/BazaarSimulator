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

    @Test("Arrivals are twice as fast in a peak hour, and average out over the day")
    func arrivalPeaks() {
        var parameters = TestLayouts.parameters
        parameters.peakPeriods = [TimeRange(startMinute: 11 * 60, endMinute: 12 * 60)]
        let layout = TestLayouts.hall()
        let input = SimulationInput(layout: layout, parameters: parameters, visitorTypes: TestLayouts.visitorTypes, focus: focus)
        let setup = CrowdAnalysisBuilder.setup(for: input, grid: NavigationGrid(layout: layout))
        #expect(setup.arrivalFactors.count == 180)
        #expect(abs(setup.arrivalFactors[90] - 2 * setup.arrivalFactors[10]) < 1e-9)
        #expect(abs(setup.arrivalFactors.reduce(0, +) / 180 - 1) < 1e-9)
        #expect(setup.window == 0...10_800)
        #expect(setup.arrivalFactors[149] > 0 && setup.arrivalFactors[150] == 0, "nobody arrives in the last half hour")
        #expect(Set(setup.typeIndexByPersona.values).isSubset(of: [0, 1]), "every persona is shown as a type the catalog has")
    }

    @Test("The hall is empty when the event closes")
    func emptyAtClosing() async throws {
        let analysis = try #require(await analyses(AnalysisService(), layouts: [TestLayouts.hall()]).first)
        let replay = try #require(analysis.replay)
        #expect(replay.frames.contains { !$0.visitors.isEmpty })
        #expect(replay.frames.last?.visitors.isEmpty == true)
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

    @Test("Live progress stays monotonic below 100 percent until every layout finishes")
    func liveProgressCoversAllLayouts() async {
        let service = AnalysisService()
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6)]
        final class ProgressBox: @unchecked Sendable {
            let lock = NSLock()
            var values: [Double] = []
        }
        let box = ProgressBox()
        let results = await service.analyses(
            for: layouts,
            parameters: TestLayouts.parameters,
            visitorTypes: TestLayouts.visitorTypes,
            focus: focus,
            legend: Legend(),
            onLiveFrame: { _, _, progress in
                box.lock.lock()
                box.values.append(progress)
                box.lock.unlock()
            }
        )
        #expect(results.count == 2)
        #expect(!box.values.isEmpty)
        #expect(box.values.allSatisfy { $0 >= 0.0 && $0 < 1.0 })
        #expect(zip(box.values, box.values.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
    }
}
