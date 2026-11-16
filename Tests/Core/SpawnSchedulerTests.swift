import Testing
@testable import BazaarSimulator

@Suite
struct SpawnSchedulerTests {
    private func arrivals(
        _ parameters: EventParameters = TestLayouts.parameters,
        people: Int = 600,
        seed: UInt64 = 1
    ) -> [Arrival] {
        var generator = SeededGenerator(seed: seed)
        return SpawnScheduler.arrivals(
            parameters: parameters,
            visitorTypes: TestLayouts.visitorTypes,
            simulatedPeople: people,
            generator: &generator
        )
    }

    @Test("Every requested person arrives, in groups no bigger than the group size")
    func totalAndGroupSize() {
        let result = arrivals()
        #expect(result.reduce(0) { $0 + $1.people } == 600)
        #expect(result.allSatisfy { (1...3).contains($0.people) })
    }

    @Test("A group size of 1 sends people one by one")
    func singleGroups() {
        var parameters = TestLayouts.parameters
        parameters.groupSize = 1
        #expect(arrivals(parameters).count == 600)
    }

    @Test("Arrivals fall inside the event and come in order")
    func insideEvent() {
        let result = arrivals()
        #expect(result.allSatisfy { $0.time >= 0 && $0.time < 3 * 3600 })
        #expect(result == result.sorted { $0.time < $1.time })
    }

    @Test("The same seed gives the same arrivals, another seed does not")
    func seeded() {
        #expect(arrivals(seed: 5) == arrivals(seed: 5))
        #expect(arrivals(seed: 5) != arrivals(seed: 6))
    }

    @Test("A peak period draws more arrivals than the same stretch without one")
    func peakPeriodIsBusier() {
        var parameters = TestLayouts.parameters
        let peak = TimeRange(startMinute: 11 * 60, endMinute: 12 * 60)
        func share(in range: TimeRange, _ parameters: EventParameters) -> Double {
            let result = arrivals(parameters, people: 20_000)
            let inside = result.filter {
                let minute = parameters.eventHours.startMinute + Int($0.time / 60)
                return minute >= range.startMinute && minute < range.endMinute
            }.reduce(0) { $0 + $1.people }
            return Double(inside) / 20_000
        }
        let without = share(in: peak, parameters)
        parameters.peakPeriods = [peak]
        #expect(share(in: peak, parameters) > without + 0.1)
    }

    @Test("The mix decides which types arrive")
    func mixDecidesTypes() {
        var parameters = TestLayouts.parameters
        parameters.mix = VisitorMix(shares: [.init(id: "a", percent: 0), .init(id: "b", percent: 100)])
        #expect(arrivals(parameters).allSatisfy { $0.typeIndex == 1 })
    }

    @Test("No people, no hours, or no types means no arrivals")
    func nothingToSpawn() {
        #expect(arrivals(people: 0).isEmpty)
        var parameters = TestLayouts.parameters
        parameters.eventHours = TimeRange(startMinute: 600, endMinute: 600)
        #expect(arrivals(parameters).isEmpty)
    }
}
