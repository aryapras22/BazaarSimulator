import Foundation

/// A simple deterministic random number generator so simulation runs are repeatable.
struct SeededRandom: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    /// Returns a random Double between 0.0 and 1.0.
    mutating func nextDouble() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58476D1CE4E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D049BB133111EB
        mixed ^= mixed >> 31
        return Double(mixed >> 11) / Double(1 << 53)
    }

    /// Returns a random Double inside the given range.
    mutating func randomDouble(in range: ClosedRange<Double>) -> Double {
        let fraction = nextDouble()
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }

    /// Returns a random Int inside the given range.
    mutating func randomInt(in range: ClosedRange<Int>) -> Int {
        let span = max(1, range.upperBound - range.lowerBound + 1)
        let offset = Int(nextDouble() * Double(span))
        return min(range.upperBound, range.lowerBound + offset)
    }

    /// Returns an exponentially distributed wait time for a given rate.
    mutating func nextExponential(rate: Double) -> Double {
        let safeRate = max(0.000_001, rate)
        let uniform = max(0.000_001, 1.0 - nextDouble())
        return -log(uniform) / safeRate
    }
}
