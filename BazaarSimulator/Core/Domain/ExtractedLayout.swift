import Foundation
import simd

struct LayoutDimensions: Sendable, Hashable, Codable {
    let width: Double
    let height: Double
}

struct ExtractedLayout: Identifiable, Sendable, Hashable, Codable {
    var layout: Layout

    var id: UUID { layout.id }

    var name: String {
        get { layout.name }
        set { layout.name = newValue }
    }

    var sizeInMetres: LayoutDimensions {
        LayoutDimensions(width: layout.sizeM.x, height: layout.sizeM.y)
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

    init(
        id: UUID = UUID(),
        name: String,
        sizeInMetres: LayoutDimensions = LayoutDimensions(width: 0, height: 0),
        booths: Int = 0,
        doors: Int = 0
    ) {
        var objects: [LayoutObject] = []
        for idx in 0..<booths {
            objects.append(
                LayoutObject(
                    kind: .booth,
                    label: "B\(idx + 1)",
                    placement: Placement(center: .zero, sizeM: SIMD2<Double>(2, 2))
                )
            )
        }
        for idx in 0..<doors {
            objects.append(
                LayoutObject(
                    kind: .door,
                    label: "Door \(idx + 1)",
                    placement: Placement(center: .zero, sizeM: SIMD2<Double>(2, 0.3)),
                    doorFlow: DoorFlow(direction: .both)
                )
            )
        }
        self.layout = Layout(
            id: id,
            name: name,
            sizeM: SIMD2<Double>(sizeInMetres.width, sizeInMetres.height),
            objects: objects
        )
    }
}
