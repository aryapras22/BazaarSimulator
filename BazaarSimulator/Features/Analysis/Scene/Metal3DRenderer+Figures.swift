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

    /// The parts of every person drawn. One visitor alone stands on its spot. A group stands in a ring
    /// around it, turned by the visitor's id so groups do not all line up the same way, and every third
    /// member of a group of three or more is a child. The body is the visitor type's color, the head a
    /// lighter tint of it so the type still reads from straight above, and the legs a darker shade.
    func figureInstances(
        _ visitors: [SimulationSceneFrame.Visitor]
    ) -> FigureInstances {
        var bodies: [Instance] = [], heads: [Instance] = [], limbs: [Instance] = []
        bodies.reserveCapacity(visitors.count)
        heads.reserveCapacity(visitors.count)
        limbs.reserveCapacity(visitors.count * 4)
        var seen: [Int: (place: SIMD2<Float>, heading: Float)] = [:]
        seen.reserveCapacity(visitors.count)

        for visitor in visitors {
            let place = SIMD2(Float(visitor.x), Float(visitor.z))
            let remembered = heading(of: visitor.id, at: place)
            seen[visitor.id] = remembered
            let heading = remembered.heading

            let color = Self.visitorColors[visitor.typeIndex % Self.visitorColors.count]
            let tone = SIMD3(color.x, color.y, color.z)
            let headColor = SIMD4(simd_mix(tone, SIMD3<Float>(1, 1, 1), SIMD3<Float>(repeating: 0.45)), color.w)
            let legColor = SIMD4(tone * 0.6, color.w)
            let count = min(max(visitor.people, 1), Self.figuresPerGroup)
            let ring: Float = count == 1 ? 0 : 0.22 + 0.08 * Float(count)
            // The way the figure's own left-to-right runs on the floor, for placing its legs and arms.
            let across = SIMD2(cos(heading), -sin(heading))

            for index in 0..<count {
                let angle = (Float(index) / Float(count)) * 2 * .pi + Float(visitor.id % 7)
                let foot = place + ring * SIMD2(cos(angle), sin(angle))
                let size: Float = count >= 3 && index % 3 == 2 ? Self.childScale : 1
                func instance(
                    _ side: Float, _ height: Float, _ scale: SIMD3<Float>, _ outline: Outline, _ color: SIMD4<Float>
                ) -> Instance {
                    let spot = foot + across * side * size
                    return Instance(
                        positionRotation: SIMD4(spot.x, height * size, spot.y, heading),
                        scale: SIMD4(scale * size, outline.rawValue), color: color
                    )
                }
                let bodyCenter = Self.visitorHeight - Self.headDiameter * 0.8 - Self.bodyHeight / 2
                let leg = SIMD3(Self.legWidth, Self.legHeight, Self.legWidth)
                let arm = SIMD3(Self.armWidth, Self.armLength, Self.armWidth)
                let shoulder = Self.bodyRadius + Self.armWidth / 2 - 0.02
                let armCenter = bodyCenter + Self.bodyHeight / 2 - 0.1 - Self.armLength / 2
                for side in [Float(-1), 1] {
                    limbs.append(instance(side * 0.08, Self.legHeight / 2, leg, .can, legColor))
                    limbs.append(instance(side * shoulder, armCenter, arm, .can, color))
                }
                bodies.append(instance(0, bodyCenter, SIMD3(1, 1, Self.bodyDepth), .figure, color))
                heads.append(instance(0, Self.visitorHeight - Self.headDiameter / 2, SIMD3(1, 1, 1), .figure, headColor))
            }
        }
        headings = seen
        return FigureInstances(bodies: bodies, heads: heads, limbs: limbs)
    }

    /// Which way a visitor faces: the way it has moved since the place it was last seen to move from. Until
    /// it has gone a couple of centimeters it keeps its old heading and its old place, so slow steps add up
    /// instead of being lost. Zero faces the bottom of the plan.
    private func heading(of id: Int, at place: SIMD2<Float>) -> (place: SIMD2<Float>, heading: Float) {
        guard let last = headings[id] else { return (place, 0) }
        let moved = place - last.place
        return simd_length_squared(moved) > 0.0004 ? (place, atan2(moved.x, moved.y)) : last
    }
}
