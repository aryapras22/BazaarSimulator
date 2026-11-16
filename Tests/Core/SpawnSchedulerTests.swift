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

    @Test("Every requested person arrives, in groups between 1 and 5")
    func totalAndGroupSize() {
        let result = arrivals()
        #expect(result.reduce(0) { $0 + $1.people } == 600)
        #expect(result.allSatisfy { (1...5).contains($0.people) })
    }

    @Test("Group sizes follow a normal distribution from 1 to 5 centered at 3")
    func groupSizeNormalDistribution() {
        var generator = SeededGenerator(seed: 42)
        var counts: [Int: Int] = [:]
        let draws = 3000
        for _ in 0..<draws {
            let size = SpawnScheduler.drawGroupSize(generator: &generator)
            #expect((1...5).contains(size))
            counts[size, default: 0] += 1
        }
        for size in 1...5 {
            #expect((counts[size] ?? 0) > 0)
        }
        #expect((counts[3] ?? 0) > (counts[2] ?? 0))
        #expect((counts[3] ?? 0) > (counts[4] ?? 0))
        #expect((counts[2] ?? 0) > (counts[1] ?? 0))
        #expect((counts[4] ?? 0) > (counts[5] ?? 0))
        let totalPeople = counts.reduce(0) { $0 + $1.key * $1.value }
        let mean = Double(totalPeople) / Double(draws)
        #expect(abs(mean - 3.0) < 0.15)
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
