import Foundation
import simd

struct BoothSizeKey: Hashable, Sendable, Comparable {
    let shortM: Double
    let longM: Double

    var title: String {
        "\(DimensionInput.text(for: shortM)) × \(DimensionInput.text(for: longM)) m"
    }

    static func < (lhs: BoothSizeKey, rhs: BoothSizeKey) -> Bool {
        (lhs.shortM, lhs.longM) < (rhs.shortM, rhs.longM)
    }
}

enum BoothGroupKind: Hashable, Sendable {
    case name(prefix: String)
    case size(BoothSizeKey)
}

struct BoothGroup: Identifiable, Hashable, Sendable {
    var id: BoothGroupKind { kind }
    let kind: BoothGroupKind
    let memberIDs: [UUID]
    let clusters: [[UUID]]

    var title: String {
        switch kind {
        case .name(let prefix): return prefix
        case .size(let key): return key.title
        }
    }
}

enum BoothGrouping {
    static let sizeBucketM = 0.5
    static let clusterGapM = 0.3

    static func namePrefix(of label: String) -> String {
        let letters = label.prefix { $0.isLetter }
        return letters.isEmpty ? "#" : letters.uppercased()
    }

    static func sizeKey(of placement: Placement) -> BoothSizeKey {
        func bucket(_ value: Double) -> Double { (value / sizeBucketM).rounded() * sizeBucketM }
        let first = bucket(placement.sizeM.x)
        let second = bucket(placement.sizeM.y)
        return BoothSizeKey(shortM: min(first, second), longM: max(first, second))
    }

    static func nameGroups(in layout: Layout) -> [BoothGroup] {
        let booths = layout.objects.filter { $0.kind == .booth }
        let grouped = Dictionary(grouping: booths) { namePrefix(of: $0.label) }
        return grouped.keys.sorted().map { prefix in
            makeGroup(kind: .name(prefix: prefix), members: grouped[prefix] ?? [])
        }
    }

    static func sizeGroups(in layout: Layout) -> [BoothGroup] {
        let booths = layout.objects.filter { $0.kind == .booth }
        let grouped = Dictionary(grouping: booths) { sizeKey(of: $0.placement) }
        return grouped.keys
            .sorted { lhs, rhs in
                let lhsCount = grouped[lhs]?.count ?? 0
                let rhsCount = grouped[rhs]?.count ?? 0
                return lhsCount != rhsCount ? lhsCount > rhsCount : lhs < rhs
            }
            .map { key in makeGroup(kind: .size(key), members: grouped[key] ?? []) }
    }

    static func group(_ kind: BoothGroupKind, in layout: Layout) -> BoothGroup? {
        switch kind {
        case .name: return nameGroups(in: layout).first { $0.kind == kind }
        case .size: return sizeGroups(in: layout).first { $0.kind == kind }
        }
    }

    static func nameKind(for booth: LayoutObject) -> BoothGroupKind {
        .name(prefix: namePrefix(of: booth.label))
    }

    static func sizeKind(for booth: LayoutObject) -> BoothGroupKind {
        .size(sizeKey(of: booth.placement))
    }

    private static func makeGroup(kind: BoothGroupKind, members: [LayoutObject]) -> BoothGroup {
        BoothGroup(kind: kind, memberIDs: members.map(\.id), clusters: clusters(of: members))
    }

    /// Booths whose bounding boxes are less than `clusterGapM` apart on both axes are joined.
    /// Clusters keep the order in which their first member appears in `members`.
    static func clusters(of members: [LayoutObject]) -> [[UUID]] {
        let boxes = members.map { LayoutGeometry.bounds(of: $0.placement) }
        var parent = Array(members.indices)
        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }
        for first in members.indices {
            for second in members.indices where second > first {
                let gapX = max(boxes[first].minX, boxes[second].minX) - min(boxes[first].maxX, boxes[second].maxX)
                let gapY = max(boxes[first].minY, boxes[second].minY) - min(boxes[first].maxY, boxes[second].maxY)
                if gapX < clusterGapM && gapY < clusterGapM {
                    parent[root(first)] = root(second)
                }
            }
        }
        var clusterIndexByRoot: [Int: Int] = [:]
        var result: [[UUID]] = []
        for index in members.indices {
            let key = root(index)
            if let clusterIndex = clusterIndexByRoot[key] {
                result[clusterIndex].append(members[index].id)
            } else {
                clusterIndexByRoot[key] = result.count
                result.append([members[index].id])
            }
        }
        return result
    }
}
