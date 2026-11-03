import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct ClickSequenceTests {
    private let interval: TimeInterval = 0.5

    @Test("Two clicks on one booth within the interval are a double click")
    func sameBoothWithinIntervalIsDoubleClick() {
        var sequence = ClickSequence()
        let booth = UUID()

        let first = sequence.register(id: booth, at: 10, interval: interval)
        let second = sequence.register(id: booth, at: 10.3, interval: interval)

        #expect(!first)
        #expect(second)
    }

    @Test("Clicks on two booths are not a double click")
    func differentBoothsAreNotDoubleClick() {
        var sequence = ClickSequence()

        _ = sequence.register(id: UUID(), at: 10, interval: interval)
        let second = sequence.register(id: UUID(), at: 10.1, interval: interval)

        #expect(!second)
    }

    @Test("A second click after the interval is not a double click")
    func lateClickIsNotDoubleClick() {
        var sequence = ClickSequence()
        let booth = UUID()

        _ = sequence.register(id: booth, at: 10, interval: interval)
        let second = sequence.register(id: booth, at: 11, interval: interval)

        #expect(!second)
    }
}
