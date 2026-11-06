import Foundation
import simd

extension LayoutEditorViewModel {
    func refreshTemplates() {
        let key = boothTemplateKey()
        guard key != templateKey else { return }
        templateKey = key
        cachedBoothTemplates = BoothTemplates.templates(layouts: layouts, legend: legend)
    }

    /// Hashes only what `BoothTemplates` reads, so moving a booth leaves the key unchanged.
    private func boothTemplateKey() -> Int {
        var hasher = Hasher()
        for layout in layouts {
            for object in layout.objects where object.kind == .booth {
                hasher.combine(object.categoryID)
                hasher.combine(BoothGrouping.sizeKey(of: object.placement))
            }
        }
        hasher.combine(legend.entries.map(\.id))
        return hasher.finalize()
    }

    var libraryRows: [LibraryRowDisplay] {
        var rows: [LibraryRowDisplay] = []

        if activeLayer == .booths {
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
        }

        let catalogRows = ObjectCatalog.items
            .filter { $0.category.layer == activeLayer }
            .map { item -> LibraryRowDisplay in
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

        if let selectedCategory = libraryCategory, selectedCategory.layer == activeLayer {
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
        guard row.category.layer == activeLayer else { return }
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
                if item.kind == .floor {
                    selectTool(.floor(itemID: id))
                } else {
                    selectTool(.blockedArea)
                }
            case .point:
                selectTool(.place(row.source))
            }
        }
    }

    func rotatePlacement() {
        placementRotationDegrees = (placementRotationDegrees + 90) % 360
        if let currentCandidate = placementPreview {
            updatePlacementPreview(at: currentCandidate.placement.center, free: false)
        }
    }

    func updatePlacementPreview(at world: SIMD2<Double>, free: Bool) {
        guard case .place(let source) = tool, let layout = activeLayout else {
            placementPreview = nil
            return
        }

        let kind: LayoutObjectKind
        let size: SIMD2<Double>
        switch source {
        case .template(let template):
            kind = .booth
            size = SIMD2<Double>(template.sizeKey.shortM, template.sizeKey.longM)
        case .catalog(let itemID):
            guard let item = ObjectCatalog.item(itemID) else {
                placementPreview = nil
                return
            }
            kind = item.kind
            size = item.sizeM
        }

        placementPreview = PlacementResolver.resolve(
            size: size,
            at: world,
            extraRotationDegrees: placementRotationDegrees,
            kind: kind,
            in: layout,
            pointsPerMetre: transform.scale,
            free: free
        )
    }

    func commitPlacement(keepTool: Bool) {
        guard let candidate = placementPreview,
              candidate.isValid,
              let layout = activeLayout,
              case .place(let source) = tool else { return }

        withSingleRefresh {
            switch source {
            case .template(let template):
                commitTemplatePlacement(candidate: candidate, template: template, in: layout)
            case .catalog(let itemID):
                commitCatalogPlacement(candidate: candidate, itemID: itemID, in: layout)
            }
        }

        if !keepTool {
            selectTool(.select)
        } else {
            updatePlacementPreview(at: candidate.placement.center, free: false)
        }
    }

    private func commitTemplatePlacement(
        candidate: PlacementCandidate,
        template: BoothTemplate,
        in layout: Layout
    ) {
        let objectID = UUID()
        let label = nextLabel(for: .booth, in: layout)
        var booth = LayoutObject(
            id: objectID,
            kind: .booth,
            label: label,
            placement: candidate.placement,
            categoryID: template.categoryID,
            heightM: BoothShape.panelHeightM
        )
        booth.openSides = OpenSideInference.defaultSide(for: booth, in: layout)
        commitEdit(.insert(booth, index: layout.objects.count))
        applySelection(objectID)
    }

    private func commitCatalogPlacement(
        candidate: PlacementCandidate,
        itemID: String,
        in layout: Layout
    ) {
        let item = ObjectCatalog.item(itemID)
        let kind = item?.kind ?? .block
        let label = nextLabel(for: kind, in: layout)
        let object = LayoutObject(
            id: UUID(),
            kind: kind,
            label: label,
            placement: candidate.placement,
            catalogID: itemID,
            heightM: item?.heightM
        )
        commitEdit(.insert(object, index: layout.objects.count))
        applySelection(object.id)
    }

    func placeLibraryItem(id: String, at world: SIMD2<Double>) {
        guard let layout = activeLayout else { return }
        let templatePrefix = "template:"
        let catalogPrefix = "catalog:"

        if id.hasPrefix(templatePrefix) || cachedBoothTemplates.contains(where: { $0.id == id }) {
            let templateID = id.hasPrefix(templatePrefix) ? String(id.dropFirst(templatePrefix.count)) : id
            placeDroppedTemplate(templateID: templateID, at: world, in: layout)
        } else {
            let itemID = id.hasPrefix(catalogPrefix) ? String(id.dropFirst(catalogPrefix.count)) : id
            placeDroppedCatalogItem(itemID: itemID, at: world, in: layout)
        }
    }

    private func placeDroppedTemplate(templateID: String, at world: SIMD2<Double>, in layout: Layout) {
        guard let template = cachedBoothTemplates.first(where: { $0.id == templateID }) else { return }
        let size = SIMD2<Double>(template.sizeKey.shortM, template.sizeKey.longM)
        let candidate = PlacementResolver.resolve(
            size: size,
            at: world,
            extraRotationDegrees: 0,
            kind: .booth,
            in: layout,
            free: false
        )
        guard candidate.isValid else { return }
        let objectID = UUID()
        let label = nextLabel(for: .booth, in: layout)
        var booth = LayoutObject(
            id: objectID,
            kind: .booth,
            label: label,
            placement: candidate.placement,
            categoryID: template.categoryID,
            heightM: BoothShape.panelHeightM
        )
        booth.openSides = OpenSideInference.defaultSide(for: booth, in: layout)
        withSingleRefresh {
            commitEdit(.insert(booth, index: layout.objects.count))
            applySelection(objectID)
        }
    }

    private func placeDroppedCatalogItem(itemID: String, at world: SIMD2<Double>, in layout: Layout) {
        guard let item = ObjectCatalog.item(itemID) else { return }
        let candidate = PlacementResolver.resolve(
            size: item.sizeM,
            at: world,
            extraRotationDegrees: 0,
            kind: item.kind,
            in: layout,
            free: false
        )
        guard candidate.isValid else { return }
        let label = nextLabel(for: item.kind, in: layout)
        let object = LayoutObject(
            id: UUID(),
            kind: item.kind,
            label: label,
            placement: candidate.placement,
            catalogID: item.id,
            heightM: item.heightM
        )
        withSingleRefresh {
            commitEdit(.insert(object, index: layout.objects.count))
            applySelection(object.id)
        }
    }
}
