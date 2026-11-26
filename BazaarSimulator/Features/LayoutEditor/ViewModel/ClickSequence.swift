import CoreGraphics
import Foundation

struct ClickSequence: Sendable {
    static let maxPointDistancePt: CGFloat = 8

    private var lastID: UUID?
    private var lastPoint: CGPoint?
    private var lastTime: TimeInterval = 0

    /// Returns true when this click completes a double click on the same object or near the same canvas point.
    mutating func register(
        id: UUID?,
        point: CGPoint? = nil,
        at time: TimeInterval,
        interval: TimeInterval
    ) -> Bool {
        defer {
            lastID = id
            lastPoint = id == nil ? point : nil
            lastTime = time
        }
        guard time - lastTime <= interval else { return false }
        if let id {
            return id == lastID
        }
        guard lastID == nil, let point, let lastPoint else { return false }
        return hypot(point.x - lastPoint.x, point.y - lastPoint.y) <= Self.maxPointDistancePt
    }
}
