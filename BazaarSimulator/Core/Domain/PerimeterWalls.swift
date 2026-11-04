import Foundation
import simd

struct WallSpan: Equatable, Sendable {
    let start: SIMD2<Double>
    let end: SIMD2<Double>
    let bottom: Double
    let top: Double
}

enum PerimeterWalls {
    static let heightM = 3.0
    static let lintelM = 2.1
    static let doorReachM = 0.3

    /// Spans for every hall and lobby edge, split around doors that sit on the edge, with a lintel span over each door.
    static func spans(for layout: Layout) -> [WallSpan] {
        var allSpans: [WallSpan] = []

        // Hall edges
        if layout.hall.count >= 3 {
            for index in 0..<layout.hall.count {
                let nextIndex = (index + 1) % layout.hall.count
                let start = layout.hall[index]
                let end = layout.hall[nextIndex]
                allSpans.append(contentsOf: spansForEdge(start: start, end: end, in: layout))
            }
        }

        // Lobby edges (only those that do not touch the hall)
        if layout.lobby.count >= 3 {
            for index in 0..<layout.lobby.count {
                let nextIndex = (index + 1) % layout.lobby.count
                let start = layout.lobby[index]
                let end = layout.lobby[nextIndex]
                let midpoint = (start + end) / 2.0
                let touchesHall = !layout.hall.isEmpty && distanceToPolygon(midpoint, polygon: layout.hall) <= 0.5
                if !touchesHall {
                    allSpans.append(contentsOf: spansForEdge(start: start, end: end, in: layout))
                }
            }
        }

        return allSpans
    }

    private static func spansForEdge(
        start: SIMD2<Double>,
        end: SIMD2<Double>,
        in layout: Layout
    ) -> [WallSpan] {
        let edgeVec = end - start
        let edgeLen = length(edgeVec)
        guard edgeLen > 1e-4 else { return [] }
        let dir = edgeVec / edgeLen

        // Find wall objects covering part of this edge (e.g. lobby wall)
        var coveredIntervals: [(Double, Double)] = []
        for object in layout.objects where object.kind == .wall {
            let dist = distanceToSegment(object.placement.center, start: start, end: end)
            if dist <= 0.3 {
                let toCenter = object.placement.center - start
                let centerT = dot(toCenter, dir)
                let halfW = object.placement.sizeM.x / 2.0
                let startT = min(max(centerT - halfW, 0.0), edgeLen)
                let endT = min(max(centerT + halfW, 0.0), edgeLen)
                if endT - startT > 1e-4 {
                    coveredIntervals.append((startT, endT))
                }
            }
        }

        // Subtract covered intervals from [0, edgeLen]
        let freeIntervals = subtractIntervals(coveredIntervals, from: [(0.0, edgeLen)])

        // Find doors sitting on this edge
        var doorIntervals: [(Double, Double)] = []
        for object in layout.objects where object.kind == .door {
            if let host = DoorHosting.nearestHost(to: object.placement.center, in: layout, reach: doorReachM),
               isSameEdge(hostStart: host.start, hostEnd: host.end, edgeStart: start, edgeEnd: end) {
                let toCenter = object.placement.center - start
                let centerT = dot(toCenter, dir)
                let halfW = object.placement.sizeM.x / 2.0
                let startT = min(max(centerT - halfW, 0.0), edgeLen)
                let endT = min(max(centerT + halfW, 0.0), edgeLen)
                if endT - startT > 1e-4 {
                    doorIntervals.append((startT, endT))
                }
            }
        }
        doorIntervals.sort { $0.0 < $1.0 }

        var result: [WallSpan] = []
        for interval in freeIntervals {
            result.append(contentsOf: buildSpans(
                interval: interval,
                doors: doorIntervals,
                start: start,
                dir: dir
            ))
        }
        return result
    }

    private static func buildSpans(
        interval: (Double, Double),
        doors: [(Double, Double)],
        start: SIMD2<Double>,
        dir: SIMD2<Double>
    ) -> [WallSpan] {
        var result: [WallSpan] = []
        var currentT = interval.0

        let relevantDoors = doors.filter { $0.1 > interval.0 && $0.0 < interval.1 }
        for door in relevantDoors {
            let doorStart = max(door.0, interval.0)
            let doorEnd = min(door.1, interval.1)

            if doorStart - currentT > 1e-4 {
                result.append(WallSpan(
                    start: start + dir * currentT,
                    end: start + dir * doorStart,
                    bottom: 0.0,
                    top: heightM
                ))
            }
            if doorEnd - doorStart > 1e-4 {
                result.append(WallSpan(
                    start: start + dir * doorStart,
                    end: start + dir * doorEnd,
                    bottom: lintelM,
                    top: heightM
                ))
            }
            currentT = max(currentT, doorEnd)
        }

        if interval.1 - currentT > 1e-4 {
            result.append(WallSpan(
                start: start + dir * currentT,
                end: start + dir * interval.1,
                bottom: 0.0,
                top: heightM
            ))
        }

        return result
    }

    private static func subtractIntervals(
        _ cuts: [(Double, Double)],
        from source: [(Double, Double)]
    ) -> [(Double, Double)] {
        var current = source
        for cut in cuts {
            var next: [(Double, Double)] = []
            for item in current {
                if cut.1 <= item.0 || cut.0 >= item.1 {
                    next.append(item)
                } else {
                    if cut.0 - item.0 > 1e-4 {
                        next.append((item.0, cut.0))
                    }
                    if item.1 - cut.1 > 1e-4 {
                        next.append((cut.1, item.1))
                    }
                }
            }
            current = next
        }
        return current
    }

    private static func isSameEdge(
        hostStart: SIMD2<Double>,
        hostEnd: SIMD2<Double>,
        edgeStart: SIMD2<Double>,
        edgeEnd: SIMD2<Double>
    ) -> Bool {
        let forwardMatch = length(hostStart - edgeStart) < 1e-3 && length(hostEnd - edgeEnd) < 1e-3
        let reverseMatch = length(hostStart - edgeEnd) < 1e-3 && length(hostEnd - edgeStart) < 1e-3
        return forwardMatch || reverseMatch
    }

    private static func distanceToSegment(_ point: SIMD2<Double>, start: SIMD2<Double>, end: SIMD2<Double>) -> Double {
        let seg = end - start
        let lenSq = dot(seg, seg)
        guard lenSq > 1e-6 else { return length(point - start) }
        let projection = dot(point - start, seg) / lenSq
        let clamped = min(max(projection, 0.0), 1.0)
        let nearest = start + seg * clamped
        return length(point - nearest)
    }

    private static func distanceToPolygon(_ point: SIMD2<Double>, polygon: [SIMD2<Double>]) -> Double {
        guard polygon.count >= 2 else { return .infinity }
        var minDistance = Double.infinity
        for index in 0..<polygon.count {
            let nextIndex = (index + 1) % polygon.count
            let dist = distanceToSegment(point, start: polygon[index], end: polygon[nextIndex])
            if dist < minDistance {
                minDistance = dist
            }
        }
        return minDistance
    }
}
