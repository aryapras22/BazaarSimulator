import Foundation

/// A span of the day in minutes from midnight. `endMinute` may be 1440 (24:00).
struct TimeRange: Codable, Sendable, Hashable {
    static let minutesPerDay = 24 * 60

    var startMinute: Int
    var endMinute: Int

    var durationMinutes: Int { endMinute - startMinute }
    var label: String { "\(Self.format(startMinute)) - \(Self.format(endMinute))" }

    static func format(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Reads "H:mm", "HH:mm", or "HHmm". Returns nil for anything outside 00:00 to 24:00.
    static func minutes(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        let hour: Int?
        let minute: Int?
        if parts.count == 2 {
            hour = Int(parts[0])
            minute = Int(parts[1])
        } else if parts.count == 1, trimmed.count == 4, trimmed.allSatisfy(\.isNumber) {
            hour = Int(trimmed.prefix(2))
            minute = Int(trimmed.suffix(2))
        } else {
            return nil
        }
        guard let hour, let minute, (0..<60).contains(minute), hour >= 0 else { return nil }
        let total = hour * 60 + minute
        return total <= minutesPerDay ? total : nil
    }
}
