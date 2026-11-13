import Foundation
import simd

/// How one visitor's figure moves from one drawn frame to the next: which way it faces, how far through
/// a stride it is, and how fully it is walking. Positions are in layout meters and times in seconds of
/// real time, so the walk looks the same however fast the simulation is played.
struct FigureGait: Equatable {
    /// Radians a figure can turn in a second.
    static let turnRate: Float = 10
    /// A figure takes a fifth of a second to break into a full walk, and the same to come to rest.
    static let easeRate: Float = 5
    /// Meters covered by two steps, one with each leg.
    static let strideLength: Float = 1.4
    /// Strides a second, however slowly or quickly the visitor moves across the floor.
    static let cadence: ClosedRange<Float> = 1.0...2.4
    /// How far a leg swings forward and back at full walk, in radians.
    static let legSwing: Float = 0.6
    /// A move this long in one frame is the timeline being scrubbed, not a step.
    static let jump: Float = 3

    /// Where the visitor last moved from, for working out its heading.
    private var anchor: SIMD2<Float>
    private var last: SIMD2<Float>
    private var target: Float = 0
    /// The way the figure faces now. Zero faces the bottom of the plan.
    private(set) var heading: Float = 0
    /// How far through a stride, in radians.
    private(set) var phase: Float = 0
    /// 0 standing, 1 walking fully.
    private(set) var walk: Float = 0

    init(at place: SIMD2<Float>) {
        anchor = place
        last = place
    }

    /// Moves the figure on to `place`, `seconds` after it was last posed.
    mutating func step(to place: SIMD2<Float>, seconds: Float) {
        let moved = simd_length(place - last)
        last = place
        guard moved < Self.jump else {
            anchor = place
            walk = 0
            return
        }
        // Until it has gone a couple of centimeters it keeps its old heading, so slow steps add up.
        let fromAnchor = place - anchor
        if simd_length_squared(fromAnchor) > 0.0004 {
            target = atan2(fromAnchor.x, fromAnchor.y)
            anchor = place
        }
        guard seconds > 0 else { return }

        let turn = (target - heading + .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let shortest = (turn < 0 ? turn + 2 * .pi : turn) - .pi
        heading += min(max(shortest, -Self.turnRate * seconds), Self.turnRate * seconds)

        let speed = moved / seconds
        let isWalking = speed > 0.05
        walk = min(max(walk + (isWalking ? 1 : -1) * Self.easeRate * seconds, 0), 1)
        if isWalking {
            let strides = min(max(speed / Self.strideLength, Self.cadence.lowerBound), Self.cadence.upperBound)
            phase = (phase + 2 * .pi * strides * seconds).truncatingRemainder(dividingBy: 2 * .pi)
        }
    }

    /// How far the left leg is swung forward, in radians, for a figure `offset` radians out of step with
    /// this one. The right leg and the left arm are the opposite.
    func swing(offset: Float = 0) -> Float {
        sin(phase + offset) * Self.legSwing * walk
    }

    /// How far the body rises at the middle of each step, in meters.
    func lift(offset: Float = 0) -> Float {
        abs(sin(phase + offset)) * 0.035 * walk
    }
}
