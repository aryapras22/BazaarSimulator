import Foundation
import simd

extension VenueGeometry {
    /// An attraction, told apart by its type: a photobooth, a stage, or another kind, drawn as a competition area or a
    /// display.
    /// Its front is its first open side, or the bottom side of the plan when none is open.
    static func entertainment(_ object: LayoutObject) -> [VenueBlock] {
        let front = [OpenSides.bottom, .top, .left, .right].first { object.openSides.contains($0) } ?? .bottom
        var (width, depth) = size(of: object)
        let quarterTurns: Float
        switch front {
        case .top: quarterTurns = 2
        case .right: quarterTurns = 1
        case .left: quarterTurns = -1
        default: quarterTurns = 0
        }
        if front == .left || front == .right { swap(&width, &depth) }
        // Parts are described with the front toward +z, then the whole frame is turned to the real front.
        let base = Frame(object)
        let frame = Frame(middle: base.middle, turn: base.turn + quarterTurns * .pi / 2)

        switch EntertainmentType.resolve(catalogID: object.catalogID, label: object.label) {
        case .photobooth:
            return photobooth(width: width, depth: depth, frame: frame)
        case .other:
            let label = object.label.lowercased()
            let isCompetition = label.contains("competition") || label.contains("lomba")
            return display(width: width, depth: depth, isCompetition: isCompetition, frame: frame)
        case .stage:
            return stage(width: width, depth: depth, height: Float(object.heightM ?? 0.5), frame: frame)
        }
    }
}
