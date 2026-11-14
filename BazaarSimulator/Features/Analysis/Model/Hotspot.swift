import CoreGraphics

struct Hotspot: Identifiable, Sendable {
    let number: Int
    let name: String
    let cause: String
    let location: CGPoint

    var id: Int { number }

    static func hotspots(for layout: LayoutID) -> [Hotspot] {
        switch layout {
        case .one: layout1
        case .two: layout2
        }
    }
}

private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: x, y: y)
}

extension Hotspot {
    static let layout1 = [
        Hotspot(
            number: 1,
            name: "West Aisle",
            cause: "A narrow aisle between the west chairs and the table blocks.",
            location: point(0.189, 0.143)
        ),
        Hotspot(
            number: 2,
            name: "Food Corner",
            cause: "Every dining table sits along this one side.",
            location: point(0.163, 0.395)
        ),
        Hotspot(
            number: 3,
            name: "South East Corner",
            cause: "Stage crowds meet people turning at the booth corner.",
            location: point(0.537, 0.527)
        ),
    ]

    static let layout2 = [
        Hotspot(
            number: 1,
            name: "Center Aisle",
            cause: "Four booths around one crossing pull everyone to the same point.",
            location: point(0.684, 0.193)
        ),
    ]
}
