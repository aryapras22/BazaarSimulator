import Foundation
import simd

extension LayoutEditorViewModel {
    var isGroupsListVisible: Bool {
        activeLayer == .booths && selectionID == nil && groupSelection == nil
    }

    var nameGroupRows: [BoothGroupRowDisplay] { rows(for: nameGroups) }
    var sizeGroupRows: [BoothGroupRowDisplay] { rows(for: sizeGroups) }

    var groupClusters: [GroupClusterDisplay] {
        guard activeLayer == .booths, let layout = activeLayout else { return [] }
        let builder = ClusterBuilder(
            booths: Dictionary(uniqueKeysWithValues: layout.objects.filter { $0.kind == .booth }.map { ($0.id, $0) }),
            colors: Dictionary(uniqueKeysWithValues: legend.entries.map { ($0.id, $0.color) })
        )
        var result: [GroupClusterDisplay] = []
        for group in nameGroups {
            let isSelected = groupSelection?.kind == .group(group.kind)
            let label = isSelected ? "\(group.title) · \(group.memberIDs.count)" : group.title
            let isHovered = hoveredGroup == group.kind
            result += group.clusters.compactMap {
                builder.display(label, $0, isSelected: isSelected, isHovered: isHovered)
            }
        }
        if let selection = groupSelection {
            switch selection.kind {
            case .group(.name): break
            default:
                result += selection.clusters.compactMap {
                    builder.display(groupSelectionClusterLabel, $0, isSelected: true, isHovered: false)
                }
            }
        }
        if let hovered = hoveredGroup, case .size = hovered, let group = boothGroup(hovered) {
            result += group.clusters.compactMap { builder.display(group.title, $0, isSelected: false, isHovered: true) }
        }
        return result
    }

    private var groupSelectionClusterLabel: String {
        guard let selection = groupSelection else { return "" }
        let count = selection.memberIDs.count
        switch selection.kind {
        case .group(let kind): return "\(boothGroup(kind)?.title ?? "") · \(count)"
        case .custom: return "\(count) booths"
        }
    }

    private func rows(for groups: [BoothGroup]) -> [BoothGroupRowDisplay] {
        guard let layout = activeLayout else { return [] }
        let categoryByBooth = Dictionary(
            uniqueKeysWithValues: layout.objects.compactMap { object in object.categoryID.map { (object.id, $0) } }
        )
        return groups.map { group in
            let used = Set(group.memberIDs.compactMap { categoryByBooth[$0] })
            let colors = legend.entries.filter { used.contains($0.id) }.map(\.color)
            return BoothGroupRowDisplay(
                id: group.id,
                title: group.title,
                count: group.memberIDs.count,
                categoryColors: Array(colors.prefix(3)),
                extraCategoryCount: max(0, colors.count - 3)
            )
        }
    }
}

private struct ClusterBuilder {
    let booths: [UUID: LayoutObject]
    let colors: [UUID: LegendColor]

    func display(_ label: String, _ ids: [UUID], isSelected: Bool, isHovered: Bool) -> GroupClusterDisplay? {
        let members = ids.compactMap { booths[$0] }
        guard let first = members.first else { return nil }
        let boxes = members.map { LayoutGeometry.bounds(of: $0.placement) }
        let bounds = BoundingBox(
            minX: boxes.map(\.minX).min() ?? 0,
            maxX: boxes.map(\.maxX).max() ?? 0,
            minY: boxes.map(\.minY).min() ?? 0,
            maxY: boxes.map(\.maxY).max() ?? 0
        )
        return GroupClusterDisplay(
            label: label,
            bounds: bounds,
            categoryColor: first.categoryID.flatMap { colors[$0] },
            isSelected: isSelected,
            isHovered: isHovered
        )
    }
}
