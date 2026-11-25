import SwiftUI

// swiftlint:disable identifier_name
enum Radius {
    static let s: CGFloat = 6
    static let m: CGFloat = 10
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}
// swiftlint:enable identifier_name

extension RoundedRectangle {
    /// The shape of every button: the corner radius of the Choose files button.
    static var button: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.s) }
}
