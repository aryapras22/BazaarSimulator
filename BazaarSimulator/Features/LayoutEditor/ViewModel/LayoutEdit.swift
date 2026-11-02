import Foundation

enum LayoutEdit: Sendable, Equatable {
    case replace(before: LayoutObject, after: LayoutObject)
    case insert(LayoutObject, index: Int)
    case delete(LayoutObject, index: Int)
}
