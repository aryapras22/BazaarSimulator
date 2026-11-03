import SwiftUI

extension LegendColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}
