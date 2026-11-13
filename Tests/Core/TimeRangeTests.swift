import Testing
@testable import BazaarSimulator

@Suite
struct TimeRangeTests {
    @Test("Formats minutes as HH:mm")
    func formatting() {
        #expect(TimeRange.format(600) == "10:00")
        #expect(TimeRange.format(9 * 60 + 5) == "09:05")
        #expect(TimeRange(startMinute: 480, endMinute: 600).label == "08:00 - 10:00")
    }

    @Test("Parses H:mm, HH:mm and HHmm")
    func parsing() {
        #expect(TimeRange.minutes(from: "10:00") == 600)
        #expect(TimeRange.minutes(from: " 9:30 ") == 570)
        #expect(TimeRange.minutes(from: "2100") == 1260)
        #expect(TimeRange.minutes(from: "24:00") == 1440)
    }

    @Test("Rejects text outside the day or not a time")
    func rejects() {
        #expect(TimeRange.minutes(from: "25:00") == nil)
        #expect(TimeRange.minutes(from: "10:60") == nil)
        #expect(TimeRange.minutes(from: "abc") == nil)
        #expect(TimeRange.minutes(from: "") == nil)
        #expect(TimeRange.minutes(from: "-1:00") == nil)
    }
}
