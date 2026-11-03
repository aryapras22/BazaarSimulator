import Foundation

struct ExtractedLayout: Identifiable, Sendable, Hashable, Codable {
    var layout: Layout

    var id: UUID { layout.id }

    var name: String {
        get { layout.name }
        set { layout.name = newValue }
    }

    var booths: Int {
        layout.objects.filter { $0.kind == .booth }.count
    }

    var doors: Int {
        layout.objects.filter { $0.kind == .door }.count
    }

    init(layout: Layout) {
        self.layout = layout
    }
}
