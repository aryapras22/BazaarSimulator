import Testing
@testable import BazaarSimulator

@Suite
struct VisitorMixTests {
    private let ids = ["a", "b", "c", "d"]

    private func total(_ mix: VisitorMix) -> Int {
        mix.shares.reduce(0) { $0 + $1.percent }
    }

    @Test("An equal split adds up to 100, with leftovers going to the first types")
    func equalSplit() {
        let mix = VisitorMix(equalSplitOf: ["a", "b", "c"])
        #expect(mix.shares.map(\.percent) == [34, 33, 33])
        #expect(total(VisitorMix(equalSplitOf: ids)) == 100)
    }

    @Test("Raising one share takes from the others in proportion")
    func proportionalRescale() {
        var mix = VisitorMix(shares: [
            .init(id: "a", percent: 40), .init(id: "b", percent: 30),
            .init(id: "c", percent: 20), .init(id: "d", percent: 10)
        ])
        mix.setPercent(70, for: "a")
        #expect(mix.share(for: "a")?.percent == 70)
        #expect(mix.shares.map(\.percent) == [70, 15, 10, 5])
        #expect(total(mix) == 100)
    }

    @Test("The total stays 100 after any sequence of edits")
    func totalStaysHundred() {
        var mix = VisitorMix(equalSplitOf: ids)
        for (index, value) in [13, 77, 0, 100, 41, 58, 3].enumerated() {
            mix.setPercent(value, for: ids[index % ids.count])
            #expect(total(mix) == 100)
            #expect(mix.shares.allSatisfy { $0.percent >= 0 })
        }
    }

    @Test("A locked share does not move")
    func lockedShareStays() {
        var mix = VisitorMix(equalSplitOf: ids)
        mix.toggleLock(for: "b")
        let locked = mix.share(for: "b")?.percent
        mix.setPercent(60, for: "a")
        #expect(mix.share(for: "b")?.percent == locked)
        #expect(total(mix) == 100)
    }

    @Test("A share cannot grow past what the locked shares leave free")
    func clampedByLocks() {
        var mix = VisitorMix(shares: [
            .init(id: "a", percent: 25), .init(id: "b", percent: 25, isLocked: true),
            .init(id: "c", percent: 25), .init(id: "d", percent: 25, isLocked: true)
        ])
        #expect(mix.maxPercent(for: "a") == 50)
        mix.setPercent(100, for: "a")
        #expect(mix.share(for: "a")?.percent == 50)
        #expect(mix.share(for: "c")?.percent == 0)
        #expect(total(mix) == 100)
    }

    @Test("Shrinking a share when the others are all zero splits the rest evenly")
    func zeroWeightsSplitEvenly() {
        var mix = VisitorMix(shares: [
            .init(id: "a", percent: 100), .init(id: "b", percent: 0),
            .init(id: "c", percent: 0), .init(id: "d", percent: 0)
        ])
        mix.setPercent(70, for: "a")
        #expect(mix.shares.map(\.percent) == [70, 10, 10, 10])
    }

    @Test("A locked share, or the last free one, cannot be edited")
    func notEditable() {
        var mix = VisitorMix(equalSplitOf: ids)
        mix.toggleLock(for: "a")
        #expect(!mix.canEdit("a"))
        mix.setPercent(90, for: "a")
        #expect(mix.share(for: "a")?.percent == 25)

        mix.toggleLock(for: "b")
        mix.toggleLock(for: "c")
        #expect(!mix.canEdit("d"))
    }
}
