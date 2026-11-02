import Foundation

struct OpenSides: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8

    static let top = OpenSides(rawValue: 1 << 0)
    static let right = OpenSides(rawValue: 1 << 1)
    static let bottom = OpenSides(rawValue: 1 << 2)
    static let left = OpenSides(rawValue: 1 << 3)

    static let all: OpenSides = [.top, .right, .bottom, .left]
    static let ordered: [OpenSides] = [.top, .right, .bottom, .left]

    func rotatedToScreen(byDegrees degrees: Int) -> OpenSides {
        let turns = (((degrees / 90) % 4) + 4) % 4
        guard turns > 0 else { return self }
        var result: OpenSides = []
        for (index, side) in Self.ordered.enumerated() where contains(side) {
            let targetIndex = (index + turns) % 4
            result.insert(Self.ordered[targetIndex])
        }
        return result
    }

    static func localSide(forScreenSide screenSide: OpenSides, rotationDegrees degrees: Int) -> OpenSides {
        let turns = (((degrees / 90) % 4) + 4) % 4
        guard let index = ordered.firstIndex(of: screenSide) else { return screenSide }
        let localIndex = (index - turns + 4) % 4
        return ordered[localIndex]
    }
}

typealias StageFace = OpenSides
