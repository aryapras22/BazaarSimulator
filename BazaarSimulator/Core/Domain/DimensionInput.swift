import Foundation

enum DimensionInput {
    /// Up to two decimals, trailing zeros removed: 2.53 -> "2.53", 2.5 -> "2.5", 2.0 -> "2".
    static func text(for value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        var text = String(format: "%.2f", rounded)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// Accepts "2.5" and "2,5". Returns nil for anything that is not a number.
    static func value(from text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let parsed = Double(normalized) else { return nil }
        return (parsed * 100).rounded() / 100
    }

    /// True when the text would change the stored value.
    static func changesValue(_ text: String, current: Double) -> Bool {
        guard let parsed = value(from: text) else { return true }
        return abs(parsed - current) > 0.0005
    }
}
