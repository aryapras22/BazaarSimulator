import SwiftUI

/// What each place on the Analysis page is called. A layout is numbered by its place in the project, so "Layout 1" is
/// the project's first layout wherever it is shown, and does not become "Layout 2" when it moves to the other card.
struct LayoutNames: Sendable, Equatable {
    var names: [LayoutID: String] = [:]

    func name(_ id: LayoutID) -> String { names[id] ?? id.name }

    /// The project's own number for a layout, such as "Layout 3". The layout's place on the page names it when the
    /// project no longer has it.
    static func name(of layout: Layout, in project: [Layout], place: LayoutID) -> String {
        guard let index = project.firstIndex(where: { $0.id == layout.id }) else { return place.name }
        return "Layout \(index + 1)"
    }
}

private struct LayoutNamesKey: EnvironmentKey {
    static let defaultValue = LayoutNames()
}

extension EnvironmentValues {
    /// What the layouts on the page are called, set by the page.
    var layoutNames: LayoutNames {
        get { self[LayoutNamesKey.self] }
        set { self[LayoutNamesKey.self] = newValue }
    }
}
