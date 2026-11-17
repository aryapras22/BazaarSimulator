import Foundation

/// A group of visitors arriving together.
struct Arrival: Equatable {
    /// Seconds after the event opens.
    let time: Double
    let people: Int
    /// Index into the visitor types.
    let typeIndex: Int
}

/// Turns the event parameters into arrival times: a rate that is higher inside peak periods,
/// groups of 1 to 5 people normally distributed around 3, and visitor types drawn from the mix.
enum SpawnScheduler {
    static let peakRateMultiplier = 2.0
    static let groupSizeRange = 1...5
    static let meanGroupSize = 3.0

    static func drawGroupSize(generator: inout SeededGenerator) -> Int {
        let sample = Int((meanGroupSize + generator.gaussian()).rounded())
        return min(max(sample, groupSizeRange.lowerBound), groupSizeRange.upperBound)
    }

    static func arrivals(
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        simulatedPeople: Int,
        generator: inout SeededGenerator
    ) -> [Arrival] {
        let hours = parameters.eventHours
        guard hours.durationMinutes > 0, simulatedPeople > 0, !visitorTypes.isEmpty else { return [] }

        // The chance of arriving in each minute, higher inside peak periods.
        var cumulative: [Double] = []
        var running = 0.0
        for minute in 0..<hours.durationMinutes {
            let clock = hours.startMinute + minute
            let isPeak = parameters.peakPeriods.contains { clock >= $0.startMinute && clock < $0.endMinute }
            running += isPeak ? peakRateMultiplier : 1
            cumulative.append(running)
        }
        let typeWeights = visitorTypes.map { Double(max(parameters.mix.share(for: $0.id)?.percent ?? 0, 0)) }
        let weightTotal = typeWeights.reduce(0, +)

        var arrivals: [Arrival] = []
        var remaining = simulatedPeople
        while remaining > 0 {
            let people = min(drawGroupSize(generator: &generator), remaining)
            remaining -= people

            let target = generator.unit() * running
            let minute = cumulative.firstIndex { $0 > target } ?? cumulative.count - 1
            let time = (Double(minute) + generator.unit()) * 60

            arrivals.append(Arrival(
                time: time,
                people: people,
                typeIndex: drawType(weights: typeWeights, total: weightTotal, generator: &generator)
            ))
        }
        return arrivals.sorted { $0.time < $1.time }
    }

    private static func drawType(weights: [Double], total: Double, generator: inout SeededGenerator) -> Int {
        guard total > 0 else { return Int(generator.unit() * Double(weights.count)) }
        var target = generator.unit() * total
        for (index, weight) in weights.enumerated() {
            target -= weight
            if target < 0 { return index }
        }
        return weights.count - 1
    }
}
