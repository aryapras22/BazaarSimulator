import Foundation
import simd

extension VenueGeometry {
    private static let trussHeight: Float = 3.2
    private static let trussInset: Float = 0.1

    /// A raised deck under an open truss frame, with a backdrop and screen at the back, speaker stacks at the
    /// front corners, lamps under the truss, a band's gear on the deck, and steps up the front. The front is
    /// toward +z.
    static func stage(width: Float, depth: Float, height: Float, frame: Frame) -> [VenueBlock] {
        let back = -depth / 2
        var parts = [
            frame.part(at: SIMD3(0, height / 2, 0), size: SIMD3(width, height, depth), color: coralColor),
            frame.part(
                at: SIMD3(0, height + 1.3, back + 0.2), size: SIMD3(max(width - 0.5, 0.2), 2.6, 0.08), color: cobaltColor
            ),
            frame.part(
                at: SIMD3(0, height + 1.5, back + 0.22), size: SIMD3(width * 0.5, 1.4, 0.1), color: whiteColor
            ),
            frame.part(
                at: SIMD3(0, height + 0.02, depth / 2 - 0.125), size: SIMD3(width, 0.04, 0.25), color: yellowColor
            )
        ]
        parts += stageTruss(width: width, depth: depth, height: height, frame: frame)
        parts += stageSound(width: width, depth: depth, height: height, frame: frame)
        if width >= 4, depth >= 2.5 {
            parts += drumKit(at: SIMD3(0, height, back + 1.0), frame: frame)
        }
        let stepWidth = min(1.4, width * 0.5)
        for step in 0..<2 {
            let rise = height * Float(2 - step) / 3
            parts.append(frame.part(
                at: SIMD3(0, rise / 2, depth / 2 + 0.15 + 0.3 * Float(step)), size: SIMD3(stepWidth, rise, 0.3),
                color: creamColor
            ))
        }
        return parts
    }

    /// Four posts and four beams around the deck, with a row of lamps under the front and back beams.
    private static func stageTruss(width: Float, depth: Float, height: Float, frame: Frame) -> [VenueBlock] {
        let reachX = width / 2 - trussInset, reachZ = depth / 2 - trussInset
        let top = height + trussHeight
        var parts: [VenueBlock] = []
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            parts.append(frame.part(
                .cylinder, at: SIMD3(sx * reachX, height + trussHeight / 2, sz * reachZ),
                size: SIMD3(0.14, trussHeight, 0.14), color: frameColor
            ))
        }
        let lamps = max(2, Int(width / 1.5))
        for end in [Float(-1), 1] {
            parts.append(frame.part(at: SIMD3(0, top, end * reachZ), size: SIMD3(width, 0.16, 0.16), color: frameColor))
            parts.append(frame.part(
                at: SIMD3(end * reachX, top, 0), size: SIMD3(0.16, 0.16, max(depth - 0.36, 0.1)), color: frameColor
            ))
            for index in 0..<lamps {
                let across = (Float(index) - Float(lamps - 1) / 2) * (width - 1) / Float(max(lamps - 1, 1))
                parts.append(frame.part(
                    .cylinder, at: SIMD3(across, top - 0.2, end * reachZ), size: SIMD3(0.2, 0.24, 0.2), color: yellowColor
                ))
            }
        }
        return parts
    }

    /// A speaker stack at each front corner, two monitors facing the performers, and a microphone on a stand.
    private static func stageSound(width: Float, depth: Float, height: Float, frame: Frame) -> [VenueBlock] {
        let front = depth / 2
        var parts: [VenueBlock] = []
        for side in [Float(-1), 1] {
            let across = side * (width / 2 - 0.55)
            parts.append(frame.part(
                at: SIMD3(across, height + 0.3, front - 0.5), size: SIMD3(0.6, 0.6, 0.5), color: frameColor
            ))
            parts.append(frame.part(
                at: SIMD3(across, height + 0.6 + 0.35, front - 0.5), size: SIMD3(0.5, 0.7, 0.4), color: frameColor
            ))
            parts.append(frame.part(
                at: SIMD3(side * width * 0.15, height + 0.125, front - 0.5), size: SIMD3(0.45, 0.25, 0.35), color: frameColor
            ))
        }
        parts += [
            frame.part(.cylinder, at: SIMD3(0, height + 0.7, front - 0.9), size: SIMD3(0.04, 1.4, 0.04), color: frameColor),
            frame.part(.cylinder, at: SIMD3(0, height + 1.45, front - 0.9), size: SIMD3(0.09, 0.12, 0.09), color: frameColor)
        ]
        return parts
    }

    /// A bass drum between two floor toms, with a cymbal on a stand at each side. `base` is the middle of the
    /// kit, on the deck.
    private static func drumKit(at base: SIMD3<Float>, frame: Frame) -> [VenueBlock] {
        var parts = [
            frame.part(.cylinder, at: base + SIMD3(0, 0.225, 0), size: SIMD3(0.6, 0.45, 0.6), color: whiteColor)
        ]
        for side in [Float(-1), 1] {
            parts += [
                frame.part(.cylinder, at: base + SIMD3(side * 0.5, 0.3, 0.1), size: SIMD3(0.32, 0.6, 0.32), color: whiteColor),
                frame.part(.cylinder, at: base + SIMD3(side * 0.9, 0.55, -0.1), size: SIMD3(0.03, 1.1, 0.03), color: frameColor),
                frame.part(.cylinder, at: base + SIMD3(side * 0.9, 1.1, -0.1), size: SIMD3(0.4, 0.03, 0.4), color: yellowColor)
            ]
        }
        return parts
    }
}
