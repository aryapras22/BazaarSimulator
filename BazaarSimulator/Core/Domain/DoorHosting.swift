import Foundation
import simd

struct DoorHost: Equatable, Sendable {
    let start: SIMD2<Double>
    let end: SIMD2<Double>
    let connection: DoorConnection
    let thicknessM: Double
}

enum DoorHosting {
    static let reachM: Double = 1.2
    static let defaultThicknessM: Double = 0.2

    static func hosts(in layout: Layout) -> [DoorHost] {
        var result: [DoorHost] = []
        result.append(contentsOf: collectWallHosts(in: layout))
        result.append(contentsOf: collectHallHosts(in: layout))
        result.append(contentsOf: collectLobbyHosts(in: layout))
        return result
    }

    private static func collectWallHosts(in layout: Layout) -> [DoorHost] {
        var result: [DoorHost] = []
        for object in layout.objects where object.kind == .wall {
            let halfLength = object.placement.sizeM.x / 2.0
            let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfLength, 0), in: object.placement)
            let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfLength, 0), in: object.placement)
            let midpoint = (start + end) / 2.0
            let distHall = distanceToPolygon(midpoint, polygon: layout.hall)
            let distLobby = distanceToPolygon(midpoint, polygon: layout.lobby)

            let connection: DoorConnection?
            if !layout.lobby.isEmpty && distHall <= 0.5 && distLobby <= 0.5 {
                connection = .hallToLobby
            } else if !layout.hall.isEmpty && distHall <= 0.5 {
                connection = .hallToOutside
            } else if !layout.lobby.isEmpty && distLobby <= 0.5 {
                connection = .lobbyToOutside
            } else {
                connection = nil
            }

            if let connection {
                result.append(
                    DoorHost(start: start, end: end, connection: connection, thicknessM: object.placement.sizeM.y)
                )
            }
        }
        return result
    }

    private static func collectHallHosts(in layout: Layout) -> [DoorHost] {
        guard layout.hall.count >= 3 else { return [] }
        var result: [DoorHost] = []
        for index in 0..<layout.hall.count {
            let nextIndex = (index + 1) % layout.hall.count
            let start = layout.hall[index]
            let end = layout.hall[nextIndex]
            let midpoint = (start + end) / 2.0
            let touchesLobby = !layout.lobby.isEmpty && distanceToPolygon(midpoint, polygon: layout.lobby) <= 0.5
            let connection: DoorConnection = touchesLobby ? .hallToLobby : .hallToOutside
            result.append(DoorHost(start: start, end: end, connection: connection, thicknessM: defaultThicknessM))
        }
        return result
    }

    private static func collectLobbyHosts(in layout: Layout) -> [DoorHost] {
        guard layout.lobby.count >= 3 else { return [] }
        var result: [DoorHost] = []
        for index in 0..<layout.lobby.count {
            let nextIndex = (index + 1) % layout.lobby.count
            let start = layout.lobby[index]
            let end = layout.lobby[nextIndex]
            let midpoint = (start + end) / 2.0
            let touchesHall = !layout.hall.isEmpty && distanceToPolygon(midpoint, polygon: layout.hall) <= 0.5
            if !touchesHall {
                result.append(
                    DoorHost(start: start, end: end, connection: .lobbyToOutside, thicknessM: defaultThicknessM)
                )
            }
        }
        return result
    }

    static func nearestHost(
        to point: SIMD2<Double>,
        in layout: Layout,
        reach: Double = reachM
    ) -> DoorHost? {
        let allHosts = hosts(in: layout)
        var bestHost: DoorHost?
        var bestDistance = reach

        for host in allHosts {
            let distance = distanceToSegment(point, start: host.start, end: host.end)
            if distance <= bestDistance {
                bestDistance = distance
                bestHost = host
            }
        }
        return bestHost
    }

    static func placement(
        width: Double,
        on host: DoorHost,
        near point: SIMD2<Double>
    ) -> Placement? {
        let vector = host.end - host.start
        let hostLength = simd_length(vector)
        guard hostLength >= width else { return nil }

        let tangent = vector / hostLength
        let projection = simd_dot(point - host.start, tangent)
        let halfWidth = width / 2.0
        let clampedProjection = min(max(projection, halfWidth), hostLength - halfWidth)
        let center = host.start + tangent * clampedProjection
        let rotation = atan2(tangent.y, tangent.x)
        let size = SIMD2<Double>(width, host.thicknessM + 0.1)

        return Placement(center: center, sizeM: size, rotationRadians: rotation)
    }

    private static func distanceToSegment(_ point: SIMD2<Double>, start: SIMD2<Double>, end: SIMD2<Double>) -> Double {
        let vector = end - start
        let length = simd_length(vector)
        guard length > 1e-6 else { return simd_distance(point, start) }
        let tangent = vector / length
        let projection = simd_dot(point - start, tangent)
        let clamped = min(max(projection, 0), length)
        let closest = start + tangent * clamped
        return simd_distance(point, closest)
    }

    private static func distanceToPolygon(_ point: SIMD2<Double>, polygon: [SIMD2<Double>]) -> Double {
        guard polygon.count >= 2 else { return Double.infinity }
        var minDistance = Double.infinity
        for index in 0..<polygon.count {
            let nextIndex = (index + 1) % polygon.count
            let dist = distanceToSegment(point, start: polygon[index], end: polygon[nextIndex])
            minDistance = min(minDistance, dist)
        }
        return minDistance
    }
}
