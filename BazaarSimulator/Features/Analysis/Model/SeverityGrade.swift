import SwiftUI

enum SeverityGrade: Int, CaseIterable, Identifiable, Sendable {
    case a, b, c, d, e, f

    var id: Int { rawValue }

    var letter: String { ["A", "B", "C", "D", "E", "F"][rawValue] }

    /// The most people per m² that still count as this grade: A up to 0.08, B up to 0.27, C up to 0.45, D up to 0.72,
    /// E up to 1.8, and F above that.
    var upperDensity: Double? { [0.08, 0.27, 0.45, 0.72, 1.8, nil][rawValue] }

    /// Where the grade starts, which is where the grade before it ends.
    var lowerDensity: Double { rawValue == 0 ? 0 : SeverityGrade(rawValue: rawValue - 1)?.upperDensity ?? 0 }

    /// People are stuck from grade E on, which is anything above 0.72 people per m².
    static let heavyThreshold = SeverityGrade.e.lowerDensity

    static func grade(forDensity density: Double) -> SeverityGrade {
        allCases.first { grade in grade.upperDensity.map { density <= $0 } ?? true } ?? .f
    }

    var rangeText: String {
        switch self {
        case .a: "up to 0.08"
        case .b: "0.08–0.27"
        case .c: "0.27–0.45"
        case .d: "0.45–0.72"
        case .e: "0.72–1.8"
        case .f: "over 1.8"
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

    /// The word for the crowd at a spot, from calm to jammed, as the Crowd Level result shows it.
    var crowdLevel: String {
        switch self {
        case .a, .b: "Calm"
        case .c: "Moderate"
        case .d: "Busy"
        case .e: "Crowded"
        case .f: "Jammed"
        }
    }

    /// What that crowd is like, in a few words.
    var crowdMeaning: String {
        switch self {
        case .a: "People have the aisle to themselves"
        case .b: "People walk freely"
        case .c: "People walk easily, with a few others around"
        case .d: "People walk slower and can't easily pass"
        case .e: "People shuffle along slowly"
        case .f: "People bump into each other"
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
        case .a: Color(hex: 0x55B049)
        case .b: Color(hex: 0x788938)
        case .c: Color(hex: 0x926C2B)
        case .d: Color(hex: 0xB24A1C)
        case .e: Color(hex: 0xCE2A0E)
        case .f: Color(hex: 0xA00700)
        }
    }
}
