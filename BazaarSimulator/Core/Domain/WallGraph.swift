import Foundation
import simd

struct WallGraph: Sendable {
    static let defaultToleranceM: Double = 0.05

    enum IncidentEnd: Hashable, Sendable {
        case start
        case end
        case body
    }

    struct Incident: Hashable, Sendable {
        let wallID: UUID
        let end: IncidentEnd
    }

    struct Node: Identifiable, Hashable, Sendable {
        let id: UUID
        let position: SIMD2<Double>
        let incidents: [Incident]

        var wallIDs: Set<UUID> {
            Set(incidents.map(\.wallID))
        }

        var isTNode: Bool {
            incidents.contains { $0.end == .body }
        }
    }

    let tolerance: Double
    let nodes: [Node]
    let wallIDs: Set<UUID>
    private let wallsByID: [UUID: LayoutObject]
    private let neighboursByWallID: [UUID: Set<UUID>]
    private let nodesByWallID: [UUID: [UUID]]
    private let nodeByWallEnd: [WallEndKey: UUID]

    init(walls: [LayoutObject], tolerance: Double = WallGraph.defaultToleranceM) {
        self.tolerance = tolerance
        let wallObjects = walls.filter { $0.kind == .wall }
        self.wallIDs = Set(wallObjects.map(\.id))
        var byID: [UUID: LayoutObject] = [:]
        for wall in wallObjects {
            byID[wall.id] = wall
        }
        self.wallsByID = byID

        let endpoints = Self.extractEndpoints(from: wallObjects)
        let endpointGroups = Self.clusterEndpoints(endpoints, tolerance: tolerance)
        var clusters = Self.makeInitialClusters(endpointGroups)
        Self.detectTContacts(clusters: &clusters, walls: wallObjects, tolerance: tolerance)

        let derivedNodes = clusters.map {
            Node(id: UUID(), position: $0.position, incidents: $0.incidents)
        }
        self.nodes = derivedNodes
        self.neighboursByWallID = Self.buildNeighbours(nodes: derivedNodes, wallIDs: self.wallIDs)
        let lookups = Self.buildNodeLookups(nodes: derivedNodes)
        self.nodesByWallID = lookups.nodesByWallID
        self.nodeByWallEnd = lookups.nodeByWallEnd
    }

    init(layout: Layout, tolerance: Double = WallGraph.defaultToleranceM) {
        self.init(walls: layout.objects, tolerance: tolerance)
    }

    func node(at id: UUID) -> Node? {
        nodes.first { $0.id == id }
    }

    func node(for wallID: UUID, end: IncidentEnd) -> Node? {
        guard let nodeID = nodeByWallEnd[WallEndKey(wallID: wallID, end: end)] else { return nil }
        return node(at: nodeID)
    }

    func nodes(for wallID: UUID) -> [Node] {
        guard let nodeIDs = nodesByWallID[wallID] else { return [] }
        return nodeIDs.compactMap { node(at: $0) }
    }

    func neighbours(of wallID: UUID) -> Set<UUID> {
        neighboursByWallID[wallID] ?? []
    }

    func wall(id: UUID) -> LayoutObject? {
        wallsByID[id]
    }

    func endpoints(for wallID: UUID) -> (start: SIMD2<Double>, end: SIMD2<Double>)? {
        guard let wall = wallsByID[wallID] else { return nil }
        let halfL = wall.placement.sizeM.x / 2.0
        let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: wall.placement)
        let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: wall.placement)
        return (start, end)
    }

    func midpoint(for wallID: UUID) -> SIMD2<Double>? {
        wallsByID[wallID]?.placement.center
    }

    func nearestNode(to point: SIMD2<Double>, maximumDistance: Double? = nil) -> Node? {
        var bestNode: Node?
        var bestDistSq = maximumDistance.map { $0 * $0 } ?? Double.infinity
        for node in nodes {
            let distSq = simd_distance_squared(point, node.position)
            if distSq < bestDistSq {
                bestDistSq = distSq
                bestNode = node
            }
        }
        return bestNode
    }
}

private struct WallEndKey: Hashable {
    let wallID: UUID
    let end: WallGraph.IncidentEnd
}

private struct RawEndpoint {
    let wallID: UUID
    let end: WallGraph.IncidentEnd
    let point: SIMD2<Double>
}

private struct MutableCluster {
    var position: SIMD2<Double>
    var incidents: [WallGraph.Incident]
}

private struct DisjointSet {
    private var parent: [Int]

    init(count: Int) {
        parent = Array(0..<count)
    }

    mutating func find(_ index: Int) -> Int {
        var root = index
        while root != parent[root] {
            root = parent[root]
        }
        var curr = index
        while curr != root {
            let next = parent[curr]
            parent[curr] = root
            curr = next
        }
        return root
    }

    mutating func union(_ first: Int, _ second: Int) {
        let root1 = find(first)
        let root2 = find(second)
        if root1 != root2 {
            parent[root1] = root2
        }
    }
}

extension WallGraph {
    private static func extractEndpoints(from walls: [LayoutObject]) -> [RawEndpoint] {
        var endpoints: [RawEndpoint] = []
        endpoints.reserveCapacity(walls.count * 2)
        for wall in walls {
            let halfL = wall.placement.sizeM.x / 2.0
            let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: wall.placement)
            let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: wall.placement)
            endpoints.append(RawEndpoint(wallID: wall.id, end: .start, point: start))
            endpoints.append(RawEndpoint(wallID: wall.id, end: .end, point: end))
        }
        return endpoints
    }

    private static func clusterEndpoints(
        _ endpoints: [RawEndpoint],
        tolerance: Double
    ) -> [[RawEndpoint]] {
        guard !endpoints.isEmpty else { return [] }
        var dsu = DisjointSet(count: endpoints.count)
        let tolSq = tolerance * tolerance

        for firstIndex in 0..<endpoints.count {
            for secondIndex in (firstIndex + 1)..<endpoints.count
            where simd_distance_squared(endpoints[firstIndex].point, endpoints[secondIndex].point) <= tolSq {
                dsu.union(firstIndex, secondIndex)
            }
        }

        var groups: [Int: [RawEndpoint]] = [:]
        for (index, endpoint) in endpoints.enumerated() {
            let root = dsu.find(index)
            groups[root, default: []].append(endpoint)
        }
        return Array(groups.values)
    }

    private static func makeInitialClusters(_ endpointGroups: [[RawEndpoint]]) -> [MutableCluster] {
        endpointGroups.map { group in
            let sum = group.reduce(SIMD2<Double>(0, 0)) { $0 + $1.point }
            let avg = sum / Double(group.count)
            let incidents = group.map { Incident(wallID: $0.wallID, end: $0.end) }
            return MutableCluster(position: avg, incidents: incidents)
        }
    }

    private static func detectTContacts(
        clusters: inout [MutableCluster],
        walls: [LayoutObject],
        tolerance: Double
    ) {
        for index in clusters.indices {
            let clusterWalls = Set(clusters[index].incidents.map(\.wallID))
            for wall in walls where !clusterWalls.contains(wall.id) {
                let local = LayoutGeometry.toLocal(point: clusters[index].position, in: wall.placement)
                let halfL = wall.placement.sizeM.x / 2.0
                let isInterior = local.x > -halfL + tolerance && local.x < halfL - tolerance
                let isNearCenterline = abs(local.y) <= tolerance

                if isInterior && isNearCenterline {
                    clusters[index].incidents.append(Incident(wallID: wall.id, end: .body))
                    clusters[index].position = LayoutGeometry.toWorld(
                        local: SIMD2<Double>(local.x, 0),
                        in: wall.placement
                    )
                }
            }
        }
    }

    private static func buildNeighbours(nodes: [Node], wallIDs: Set<UUID>) -> [UUID: Set<UUID>] {
        var neighbours: [UUID: Set<UUID>] = [:]
        for wallID in wallIDs {
            neighbours[wallID] = []
        }
        for node in nodes {
            for wallID in node.wallIDs {
                let others = node.wallIDs.subtracting([wallID])
                neighbours[wallID, default: []].formUnion(others)
            }
        }
        return neighbours
    }

    private static func buildNodeLookups(
        nodes: [Node]
    ) -> (nodesByWallID: [UUID: [UUID]], nodeByWallEnd: [WallEndKey: UUID]) {
        var byWall: [UUID: [UUID]] = [:]
        var byEnd: [WallEndKey: UUID] = [:]
        for node in nodes {
            for incident in node.incidents {
                byWall[incident.wallID, default: []].append(node.id)
                if incident.end != .body {
                    byEnd[WallEndKey(wallID: incident.wallID, end: incident.end)] = node.id
                }
            }
        }
        return (byWall, byEnd)
    }
}
