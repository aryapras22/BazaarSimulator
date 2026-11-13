import Foundation

/// A whole-percent share per visitor type. The shares always add up to 100.
/// Changing one share rescales the unlocked others; locked shares never move.
struct VisitorMix: Codable, Sendable, Hashable {
    struct Share: Codable, Sendable, Hashable, Identifiable {
        let id: String
        var percent: Int
        var isLocked: Bool = false
    }

    private(set) var shares: [Share]

    /// Splits 100 as evenly as possible. The first ids take the leftover points.
    init(equalSplitOf ids: [String]) {
        let count = max(ids.count, 1)
        shares = ids.enumerated().map { index, id in
            Share(id: id, percent: 100 / count + (index < 100 % count ? 1 : 0))
        }
    }

    /// Expects `shares` to already add up to 100.
    init(shares: [Share]) {
        self.shares = shares
    }

    func share(for id: String) -> Share? {
        shares.first { $0.id == id }
    }

    /// The highest value `id` can take: 100 minus what the other locked shares hold.
    /// It is the current value when no other share is free to absorb a change.
    func maxPercent(for id: String) -> Int {
        guard let share = share(for: id) else { return 0 }
        let others = shares.filter { $0.id != id }
        guard others.contains(where: { !$0.isLocked }) else { return share.percent }
        return 100 - others.filter(\.isLocked).reduce(0) { $0 + $1.percent }
    }

    /// Whether the slider for `id` can move at all.
    func canEdit(_ id: String) -> Bool {
        guard let share = share(for: id), !share.isLocked else { return false }
        return maxPercent(for: id) > 0 && shares.contains { $0.id != id && !$0.isLocked }
    }

    mutating func setPercent(_ requested: Int, for id: String) {
        guard canEdit(id), let index = shares.firstIndex(where: { $0.id == id }) else { return }
        let value = min(max(requested, 0), maxPercent(for: id))
        let free = shares.indices.filter { $0 != index && !shares[$0].isLocked }
        let lockedTotal = shares.enumerated()
            .filter { $0.offset != index && $0.element.isLocked }
            .reduce(0) { $0 + $1.element.percent }
        let pool = 100 - lockedTotal - value
        let weights = free.map { shares[$0].percent }
        let split = Self.distribute(pool, by: weights)

        shares[index].percent = value
        for (slot, shareIndex) in free.enumerated() {
            shares[shareIndex].percent = split[slot]
        }
    }

    mutating func toggleLock(for id: String) {
        guard let index = shares.firstIndex(where: { $0.id == id }) else { return }
        shares[index].isLocked.toggle()
    }

    /// Splits `total` into whole numbers proportional to `weights` (largest remainder).
    /// All-zero weights split evenly.
    static func distribute(_ total: Int, by weights: [Int]) -> [Int] {
        guard !weights.isEmpty else { return [] }
        let sum = weights.reduce(0, +)
        let effective = sum > 0 ? weights : Array(repeating: 1, count: weights.count)
        let effectiveSum = effective.reduce(0, +)

        var result = effective.map { total * $0 / effectiveSum }
        let remainders = effective.map { total * $0 % effectiveSum }
        let leftover = total - result.reduce(0, +)
        let order = remainders.indices.sorted { remainders[$0] > remainders[$1] }
        for index in order.prefix(leftover) {
            result[index] += 1
        }
        return result
    }
}
