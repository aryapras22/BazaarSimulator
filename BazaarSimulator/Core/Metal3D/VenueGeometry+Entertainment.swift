import Foundation
import simd

extension VenueGeometry {
    /// An attraction, told apart by its type: a photobooth, a stage, or another kind, drawn as a competition area or a
    /// display.
    /// Its front is its first open side, or the bottom side of the plan when none is open.
    static func entertainment(_ object: LayoutObject) -> [VenueBlock] {
        let front = frontSide(of: object)
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
        case .informationDesk, .disabled:
            return display(width: width, depth: depth, isCompetition: false, frame: frame)
        case .stage:
            return stage(width: width, depth: depth, height: Float(object.heightM ?? 0.5), frame: frame)
        }
    }

    static func frontSide(of object: LayoutObject) -> OpenSides {
        let priority: [OpenSides] = [.bottom, .top, .left, .right]
        let open = priority.filter { object.openSides.contains($0) }
        switch open.count {
        case 1:
            return open[0]
        case 2:
            if let horizontal = [OpenSides.bottom, .top].first(where: { object.openSides.contains($0) }),
               let vertical = [OpenSides.left, .right].first(where: { object.openSides.contains($0) }),
               object.placement.sizeM.x != object.placement.sizeM.y {
                return object.placement.sizeM.x > object.placement.sizeM.y ? horizontal : vertical
            }
            return open[0]
        case 3:
            switch OpenSides.all.subtracting(object.openSides) {
            case .top: return .bottom
            case .bottom: return .top
            case .left: return .right
            case .right: return .left
            default: return .bottom
            }
        default:
            return .bottom
        }
    }
}
