import Foundation

struct ClickSequence: Sendable {
    private var lastID: UUID?
    private var lastTime: TimeInterval = 0

    /// Returns true when this click on `id` completes a double click.
    mutating func register(id: UUID?, at time: TimeInterval, interval: TimeInterval) -> Bool {
        defer {
            lastID = id
            lastTime = time
        }
        guard let id, id == lastID else { return false }
        return time - lastTime <= interval
    }
}
