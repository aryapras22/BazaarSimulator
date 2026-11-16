import Foundation

/// A small deterministic generator (SplitMix64). The same seed always gives the same run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// A number in 0..<1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// A standard normal value with mean 0 and standard deviation 1 (Box-Muller).
    mutating func gaussian() -> Double {
        let radius = (-2 * log(max(0.000_001, 1.0 - unit()))).squareRoot()
        return radius * cos(2 * Double.pi * unit())
    }
}
