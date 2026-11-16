import SwiftUI

enum SeverityGrade: Int, CaseIterable, Identifiable, Sendable {
    case a, b, c, d, e, f

    var id: Int { rawValue }

    var letter: String { ["A", "B", "C", "D", "E", "F"][rawValue] }

    var lowerDensity: Double { [0, 0.31, 0.43, 0.72, 1.08, 2.17][rawValue] }

    var upperDensity: Double? {
        self == .f ? nil : SeverityGrade(rawValue: rawValue + 1)?.lowerDensity
    }

    static let heavyThreshold = SeverityGrade.e.lowerDensity

    static func grade(forDensity density: Double) -> SeverityGrade {
        allCases.last { density >= $0.lowerDensity } ?? .a
    }

    var rangeText: String {
        switch self {
        case .a: "under 0.31"
        case .b: "0.31–0.43"
        case .c: "0.43–0.72"
        case .d: "0.72–1.08"
        case .e: "1.08–2.17"
        case .f: "over 2.17"
        }
    }

    var title: String {
        switch self {
        case .a: "Free flow"
        case .b: "Minor conflicts"
        case .c: "Restricted"
        case .d: "Crowded"
        case .e: "Stop-and-go"
        case .f: "Jammed"
        }
    }

    var shortMeaning: String {
        switch self {
        case .a: "Almost empty"
        case .b: "Quiet, easy to walk"
        case .c: "A bit busy, easy to walk"
        case .d: "Busy, but walkable"
        case .e: "Very busy, people shuffle"
        case .f: "Packed, bodies touch"
        }
    }

    var plainMeaning: String {
        switch self {
        case .a: "People have the aisle almost to themselves"
        case .b: "People walk freely"
        case .c: "People walk easily, with a few others around"
        case .d: "People walk slower and can't easily pass"
        case .e: "People shuffle along slowly"
        case .f: "People are packed and bump into each other"
        }
    }

    var meaning: String {
        switch self {
        case .a: "Walk at your own pace and pass anyone."
        case .b: "Mostly free, with the odd step aside."
        case .c: "Normal pace, but passing takes care."
        case .d: "Slower pace; passing is difficult."
        case .e: "Shuffling steps, moving with the crowd."
        case .f: "Barely moving, constant body contact."
        }
    }

    var color: Color {
        switch self {
        case .a: Color(hex: 0xCD2002)
        case .b: Color(hex: 0xB41900)
        case .c: Color(hex: 0x9B1400)
        case .d: Color(hex: 0x811100)
        case .e: Color(hex: 0x5D0900)
        case .f: Color(hex: 0x450501)
        }
    }
}
