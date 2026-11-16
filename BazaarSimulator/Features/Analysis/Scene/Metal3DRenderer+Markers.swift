import simd

extension Metal3DRenderer {
    /// A glowing disc on the floor and a beam above it for each watched spot. A more crowded spot is wider
    /// and stronger.
    func markerInstances(_ spots: [SimulationSceneFrame.Spot]) -> [Instance] {
        var instances: [Instance] = []
        for spot in spots {
            let level = Float(min(max(spot.level, 0), 1))
            let width = 2 * Self.spotRadius * (0.8 + 0.4 * level)
            var disc = Self.glowColor
            disc.w = 0.35 + 0.4 * level
            var beam = Self.glowColor
            beam.w = 0.4
            instances.append(Instance(
                positionRotation: SIMD4(Float(spot.x), 0.08, Float(spot.z), 0), scale: SIMD4(width, 0.06, width, Outline.none.rawValue), color: disc
            ))
            instances.append(Instance(
                positionRotation: SIMD4(Float(spot.x), 3, Float(spot.z), 0), scale: SIMD4(0.6, 6, 0.6, Outline.none.rawValue), color: beam
            ))
        }
        return instances
    }
}
