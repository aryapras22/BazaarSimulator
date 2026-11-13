import QuartzCore
import simd

extension Metal3DRenderer {
    /// Every person's parts, grouped by the shape that draws them.
    struct FigureInstances {
        var bodies: [Instance]
        var heads: [Instance]
        /// Legs and arms.
        var limbs: [Instance]
    }

    // A visitor is two legs, a body with two arms, and a head, `visitorHeight` tall in all.
    static let headDiameter: Float = 0.34
    static let legHeight: Float = 0.78
    static let legWidth: Float = 0.13
    static let armLength: Float = 0.58
    static let armWidth: Float = 0.1
    static let bodyRadius: Float = 0.22
    /// The body's rounded ends sink into the legs below and the head above.
    static let bodyHeight: Float = 0.86
    /// The body is flattened front to back, so the shoulders are wider than the chest is deep.
    static let bodyDepth: Float = 0.7
    static let childScale: Float = 0.62
    /// A group is drawn as this many figures at most, standing around the group's own spot.
    static let figuresPerGroup = 4

    /// The parts of every person drawn at `now`, a time in seconds. One visitor alone stands on its spot. A
    /// group stands in a ring around it, turned by the visitor's id so groups do not all line up the same
    /// way, and every third member of a group of three or more is a child. A visitor that is moving walks:
    /// its legs and arms swing and its body rises with each step. The body is the visitor type's color, the
    /// head a lighter tint of it so the type still reads from straight above, and the legs a darker shade.
    func figureInstances(
        _ visitors: [SimulationSceneFrame.Visitor], now: Double = CACurrentMediaTime()
    ) -> FigureInstances {
        var figures = FigureInstances(bodies: [], heads: [], limbs: [])
        figures.bodies.reserveCapacity(visitors.count)
        figures.heads.reserveCapacity(visitors.count)
        figures.limbs.reserveCapacity(visitors.count * 4)
        // A long gap is a pause, not one slow step.
        let seconds = Float(min(max(now - (lastFigureTime ?? now), 0), 0.1))
        lastFigureTime = now
        var seen: [Int: FigureGait] = [:]
        seen.reserveCapacity(visitors.count)

        for visitor in visitors {
            let place = SIMD2(Float(visitor.x), Float(visitor.z))
            var gait = gaits[visitor.id] ?? FigureGait(at: place)
            gait.step(to: place, seconds: seconds)
            seen[visitor.id] = gait

            let count = min(max(visitor.people, 1), Self.figuresPerGroup)
            let ring: Float = count == 1 ? 0 : 0.22 + 0.08 * Float(count)
            let color = Self.visitorColors[visitor.typeIndex % Self.visitorColors.count]
            for index in 0..<count {
                let angle = (Float(index) / Float(count)) * 2 * .pi + Float(visitor.id % 7)
                append(
                    to: &figures, gait: gait, foot: place + ring * SIMD2(cos(angle), sin(angle)),
                    size: count >= 3 && index % 3 == 2 ? Self.childScale : 1,
                    // Members of a group are out of step with each other.
                    step: Float(index) * 1.3, color: color
                )
            }
        }
        gaits = seen
        return figures
    }

    /// Adds one figure standing on `foot`. Each leg hangs from the hip and each arm from the shoulder, so a
    /// limb that swings turns about its top end.
    private func append(
        to figures: inout FigureInstances, gait: FigureGait, foot: SIMD2<Float>, size: Float, step: Float,
        color: SIMD4<Float>
    ) {
        let heading = gait.heading
        // The figure's own left-to-right and front-to-back on the floor.
        let across = SIMD2(cos(heading), -sin(heading))
        let forward = SIMD2(sin(heading), cos(heading))
        let tone = SIMD3(color.x, color.y, color.z)
        let headColor = SIMD4(simd_mix(tone, SIMD3<Float>(1, 1, 1), SIMD3<Float>(repeating: 0.45)), color.w)
        let legColor = SIMD4(tone * 0.6, color.w)
        let swing = gait.swing(offset: step)
        let lift = gait.lift(offset: step)

        func instance(
            _ side: Float, _ height: Float, _ front: Float, _ scale: SIMD3<Float>, _ outline: Outline,
            _ color: SIMD4<Float>, lean: Float = 0
        ) -> Instance {
            let spot = foot + (across * side + forward * front) * size
            return Instance(
                positionRotation: SIMD4(spot.x, height * size, spot.y, heading),
                scale: SIMD4(scale * size, outline.rawValue), color: color, tilt: SIMD4(lean, 0, 0, 0)
            )
        }
        /// A limb `length` long hanging from `top`, swung by `lean` about that end.
        func limb(_ side: Float, top: Float, length: Float, width: Float, lean: Float, _ color: SIMD4<Float>) -> Instance {
            instance(
                side, top - length / 2 * cos(lean), -length / 2 * sin(lean), SIMD3(width, length, width), .can, color,
                lean: lean
            )
        }
        let bodyCenter = Self.visitorHeight - Self.headDiameter * 0.8 - Self.bodyHeight / 2 + lift
        let shoulder = Self.bodyRadius + Self.armWidth / 2 - 0.02
        let armTop = bodyCenter + Self.bodyHeight / 2 - 0.1
        for side in [Float(-1), 1] {
            figures.limbs.append(limb(
                side * 0.08, top: Self.legHeight + lift, length: Self.legHeight, width: Self.legWidth, lean: -side * swing,
                legColor
            ))
            figures.limbs.append(limb(
                side * shoulder, top: armTop, length: Self.armLength, width: Self.armWidth, lean: side * swing * 0.7, color
            ))
        }
        figures.bodies.append(instance(0, bodyCenter, 0, SIMD3(1, 1, Self.bodyDepth), .figure, color))
        figures.heads.append(instance(
            0, Self.visitorHeight - Self.headDiameter / 2 + lift, 0, SIMD3(1, 1, 1), .figure, headColor
        ))
    }
}
