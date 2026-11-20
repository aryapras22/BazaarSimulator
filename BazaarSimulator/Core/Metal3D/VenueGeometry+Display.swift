import Foundation
import simd

extension VenueGeometry {
    private static let deckHeight: Float = 0.15
    private static let stanchionHeight: Float = 0.9
    private static let stanchionInset: Float = 0.12

    /// A low platform roped off on every side but the front, with a banner at the back. A competition area
    /// has a winners' podium and a trophy on it. A display has a row of plinths with things to look at. The
    /// front is toward +z.
    static func display(width: Float, depth: Float, isCompetition: Bool, frame: Frame) -> [VenueBlock] {
        var parts = [
            frame.part(at: SIMD3(0, deckHeight / 2, 0), size: SIMD3(width, deckHeight, depth), color: coralColor)
        ]
        parts += ropes(width: width, depth: depth, frame: frame)
        parts += banner(width: width, back: -depth / 2 + 0.3, frame: frame)
        parts += isCompetition ? podium(width: width, frame: frame) : plinths(width: width, depth: depth, frame: frame)
        return parts
    }

    /// A post at each corner, each on a foot and under a cap, with a rail between them along the back and
    /// the two sides.
    private static func ropes(width: Float, depth: Float, frame: Frame) -> [VenueBlock] {
        let reachX = width / 2 - stanchionInset, reachZ = depth / 2 - stanchionInset
        var parts: [VenueBlock] = []
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            let spot = SIMD2(sx * reachX, sz * reachZ)
            parts += [
                frame.part(
                    .cylinder, at: SIMD3(spot.x, deckHeight + stanchionHeight / 2, spot.y),
                    size: SIMD3(0.08, stanchionHeight, 0.08), color: cobaltColor
                ),
                frame.part(.cylinder, at: SIMD3(spot.x, deckHeight + 0.02, spot.y), size: SIMD3(0.3, 0.04, 0.3), color: frameColor),
                frame.part(
                    .cylinder, at: SIMD3(spot.x, deckHeight + stanchionHeight + 0.04, spot.y), size: SIMD3(0.13, 0.08, 0.13),
                    color: yellowColor
                )
            ]
        }
        let railHeight = deckHeight + stanchionHeight - 0.1
        parts.append(frame.part(at: SIMD3(0, railHeight, -reachZ), size: SIMD3(reachX * 2, 0.04, 0.04), color: vermilionColor))
        for side in [Float(-1), 1] {
            parts.append(frame.part(
                at: SIMD3(side * reachX, railHeight, 0), size: SIMD3(0.04, 0.04, reachZ * 2), color: vermilionColor
            ))
        }
        return parts
    }

    /// A board with a stripe across it, held up by two posts.
    private static func banner(width: Float, back: Float, frame: Frame) -> [VenueBlock] {
        let board = max(width * 0.7, 0.4)
        var parts = [
            frame.part(at: SIMD3(0, deckHeight + 1.5, back), size: SIMD3(board, 1.0, 0.06), color: cobaltColor),
            frame.part(at: SIMD3(0, deckHeight + 1.5, back), size: SIMD3(board * 0.8, 0.3, 0.09), color: whiteColor)
        ]
        for side in [Float(-1), 1] {
            parts.append(frame.part(
                .cylinder, at: SIMD3(side * board / 2, deckHeight + 1.0, back), size: SIMD3(0.07, 2.0, 0.07), color: frameColor
            ))
        }
        return parts
    }

    /// Three steps, the middle one highest, each with a plate on its front, and a trophy on the top step.
    private static func podium(width: Float, frame: Frame) -> [VenueBlock] {
        let step = min(0.8, (width - 0.6) / 3)
        let steps: [(across: Float, height: Float, color: SIMD4<Float>)] = [
            (0, 0.6, whiteColor), (-step, 0.4, paleBlueColor), (step, 0.25, paleBlueColor)
        ]
        var parts: [VenueBlock] = []
        for place in steps {
            parts += [
                frame.part(
                    at: SIMD3(place.across, deckHeight + place.height / 2, 0), size: SIMD3(step, place.height, 0.7),
                    color: place.color
                ),
                frame.part(
                    at: SIMD3(place.across, deckHeight + place.height / 2, 0.35), size: SIMD3(step * 0.4, 0.14, 0.04),
                    color: yellowColor
                )
            ]
        }
        return parts + trophy(at: SIMD3(0, deckHeight + 0.6, 0), frame: frame)
    }

    /// A cup: a foot, a stem, and a bowl. `base` is where it stands.
    private static func trophy(at base: SIMD3<Float>, frame: Frame) -> [VenueBlock] {
        [
            frame.part(.cylinder, at: base + SIMD3(0, 0.03, 0), size: SIMD3(0.22, 0.06, 0.22), color: frameColor),
            frame.part(.cylinder, at: base + SIMD3(0, 0.14, 0), size: SIMD3(0.06, 0.16, 0.06), color: yellowColor),
            frame.part(.cylinder, at: base + SIMD3(0, 0.33, 0), size: SIMD3(0.26, 0.22, 0.26), color: yellowColor)
        ]
    }

    /// A row of plinths of different heights, each with something on it and a caption stand in front.
    private static func plinths(width: Float, depth: Float, frame: Frame) -> [VenueBlock] {
        let count = min(max(Int(width / 1.2), 1), 4)
        let heights: [Float] = [0.9, 0.6, 1.1, 0.75]
        var parts: [VenueBlock] = []
        for index in 0..<count {
            let across = (Float(index) - Float(count - 1) / 2) * (width - 0.8) / Float(max(count, 2))
            let top = deckHeight + heights[index % heights.count]
            parts.append(frame.part(
                at: SIMD3(across, top / 2 + deckHeight / 2, 0), size: SIMD3(0.5, top - deckHeight, 0.5), color: whiteColor
            ))
            switch index % 3 {
            case 0:
                parts += trophy(at: SIMD3(across, top, 0), frame: frame)
            case 1:
                parts.append(frame.part(
                    at: SIMD3(across, top + 0.16, 0), size: SIMD3(0.3, 0.32, 0.3), color: cobaltColor, extraTurn: .pi / 4
                ))
            default:
                parts += [
                    frame.part(.cylinder, at: SIMD3(across, top + 0.2, 0), size: SIMD3(0.2, 0.4, 0.2), color: vermilionColor),
                    frame.part(.cylinder, at: SIMD3(across, top + 0.43, 0), size: SIMD3(0.3, 0.06, 0.3), color: yellowColor)
                ]
            }
            if depth >= 2 {
                parts += [
                    frame.part(
                        .cylinder, at: SIMD3(across, deckHeight + 0.35, 0.6), size: SIMD3(0.03, 0.7, 0.03), color: frameColor
                    ),
                    frame.part(at: SIMD3(across, deckHeight + 0.76, 0.6), size: SIMD3(0.3, 0.2, 0.03), color: whiteColor)
                ]
            }
        }
        return parts
    }
}
