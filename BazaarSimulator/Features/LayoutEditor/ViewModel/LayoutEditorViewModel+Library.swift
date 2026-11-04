import Foundation
import simd

extension LayoutEditorViewModel {
    var libraryRows: [LibraryRowDisplay] {
        var rows: [LibraryRowDisplay] = []

        let templateRows = cachedBoothTemplates.map { template -> LibraryRowDisplay in
            let categoryName = legend.entries.first { $0.id == template.categoryID }?.name ?? "Booth"
            let title = "\(categoryName) booth"
            let shortText = DimensionInput.text(for: template.sizeKey.shortM)
            let longText = DimensionInput.text(for: template.sizeKey.longM)
            let detail = "\(shortText) × \(longText) m · \(template.count) placed"
            let tint = legend.entries.first { $0.id == template.categoryID }?.color
            return LibraryRowDisplay(
                id: template.id,
                source: .template(template),
                title: title,
                detail: detail,
                category: .project,
                footprint: .rect,
                sizeM: SIMD2(template.sizeKey.shortM, template.sizeKey.longM),
                openSides: [.bottom],
                seats: [],
                tint: tint
            )
        }
        rows.append(contentsOf: templateRows)

        let catalogRows = ObjectCatalog.items.map { item -> LibraryRowDisplay in
            let detail: String
            if item.footprint == .circle {
                detail = "⌀ \(DimensionInput.text(for: item.sizeM.x)) m"
            } else {
                detail = "\(DimensionInput.text(for: item.sizeM.x)) × \(DimensionInput.text(for: item.sizeM.y)) m"
            }
            return LibraryRowDisplay(
                id: item.id,
                source: .catalog(item.id),
                title: item.name,
                detail: detail,
                category: item.category,
                footprint: item.footprint,
                sizeM: item.sizeM,
                openSides: [],
                seats: item.seats,
                tint: nil
            )
        }
        rows.append(contentsOf: catalogRows)

        if let selectedCategory = libraryCategory {
            rows = rows.filter { $0.category == selectedCategory }
        }

        let trimmedSearch = librarySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedSearch.isEmpty {
            rows = rows.filter { row in
                if row.title.lowercased().contains(trimmedSearch) { return true }
                if case let .catalog(id) = row.source, let item = ObjectCatalog.item(id) {
                    return item.keywords.contains { $0.lowercased().contains(trimmedSearch) }
                }
                return false
            }
        }

        return rows
    }

    func startPlacing(_ row: LibraryRowDisplay) {
        selectObject(nil)
        switch row.source {
        case .template:
            selectTool(.place(row.source))
        case .catalog(let id):
            guard let item = ObjectCatalog.item(id) else { return }
            switch item.placement {
            case .drawWall:
                selectTool(.drawWall(itemID: id))
            case .door:
                selectTool(.placeDoor(itemID: id))
            case .drawArea:
                selectTool(.blockedArea)
            case .point:
                selectTool(.place(row.source))
            }
        }
    }

    func placeLibraryItem(id: String, at world: SIMD2<Double>) {
        // Will be expanded in Step 5
    }
}
