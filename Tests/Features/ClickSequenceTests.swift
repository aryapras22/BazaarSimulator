import CoreGraphics
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

    @Test("Two nil-ID clicks near the same point within the interval are a double click")
    func nilIDNearSamePointWithinIntervalIsDoubleClick() {
        var sequence = ClickSequence()

        let first = sequence.register(id: nil, point: CGPoint(x: 100, y: 100), at: 10, interval: interval)
        let second = sequence.register(id: nil, point: CGPoint(x: 102, y: 101), at: 10.3, interval: interval)

        #expect(!first)
        #expect(second)
    }

    @Test("Two nil-ID clicks far apart are not a double click")
    func nilIDFarPointsAreNotDoubleClick() {
        var sequence = ClickSequence()

        _ = sequence.register(id: nil, point: CGPoint(x: 100, y: 100), at: 10, interval: interval)
        let second = sequence.register(id: nil, point: CGPoint(x: 150, y: 150), at: 10.1, interval: interval)

        #expect(!second)
    }

    @Test("A late nil-ID click at the same point is not a double click")
    func nilIDLateClickAtSamePointIsNotDoubleClick() {
        var sequence = ClickSequence()

        _ = sequence.register(id: nil, point: CGPoint(x: 100, y: 100), at: 10, interval: interval)
        let second = sequence.register(id: nil, point: CGPoint(x: 100, y: 100), at: 11, interval: interval)

        #expect(!second)
    }

    @Test("An object click followed by a nil-ID click at the same point is not a double click")
    func objectThenNilIDClickIsNotDoubleClick() {
        var sequence = ClickSequence()

        _ = sequence.register(id: UUID(), point: CGPoint(x: 100, y: 100), at: 10, interval: interval)
        let second = sequence.register(id: nil, point: CGPoint(x: 100, y: 100), at: 10.1, interval: interval)

        #expect(!second)
    }

    @Test("Two nil-ID clicks without a point are not a double click")
    func nilIDWithoutPointIsNotDoubleClick() {
        var sequence = ClickSequence()

        _ = sequence.register(id: nil, at: 10, interval: interval)
        let second = sequence.register(id: nil, at: 10.1, interval: interval)

        #expect(!second)
    }
}

