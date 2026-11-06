import Foundation

enum LayoutObjectNaming {
    static func nextLabel(for kind: LayoutObjectKind, in layout: Layout) -> String {
        switch kind {
        case .booth:
            return nextPrefixedLabel(prefix: "N", kind: kind, in: layout)
        case .closedArea:
            return "Blocked area"
        case .floor:
            return "Floor"
        default:
            let existingCount = layout.objects.filter { $0.kind == kind }.count + 1
            return "\(kind.displayName) \(existingCount)"
        }
    }

    static func nextPrefixedLabel(prefix: String, kind: LayoutObjectKind, in layout: Layout) -> String {
        let highest = layout.objects
            .filter { $0.kind == kind && $0.label.hasPrefix(prefix) }
            .compactMap { Int($0.label.dropFirst(prefix.count)) }
            .max() ?? 0
        return "\(prefix)\(highest + 1)"
    }
}
