import Foundation
import simd

struct WallSpan: Equatable, Sendable {
    let start: SIMD2<Double>
    let end: SIMD2<Double>
    let bottom: Double
    let top: Double
    var thickness: Double = DoorHosting.defaultThicknessM
}

private struct DoorCut {
    let start: Double
    let end: Double
    let height: Double
}

private struct WallLine {
    let start: SIMD2<Double>
    let end: SIMD2<Double>
    let top: Double
    let thickness: Double

    var length: Double { simd_length(end - start) }
    var direction: SIMD2<Double> { (end - start) / length }
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

    /// Spans for one wall object, split around doors hosted on it.
    static func spans(forWallObject object: LayoutObject, in layout: Layout) -> [WallSpan] {
        let halfLength = object.placement.sizeM.x / 2.0
        let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfLength, 0), in: object.placement)
        let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfLength, 0), in: object.placement)
        let line = WallLine(start: start, end: end, top: object.heightM ?? heightM, thickness: object.placement.sizeM.y)
        return spans(along: [(0.0, line.length)], of: line, in: layout)
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

        // Wall objects lying on the edge draw their own part of it, so the edge leaves that part out.
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

        let line = WallLine(start: start, end: end, top: heightM, thickness: DoorHosting.defaultThicknessM)
        return spans(along: subtractIntervals(coveredIntervals, from: [(0.0, edgeLen)]), of: line, in: layout)
    }

    private static func spans(
        along intervals: [(Double, Double)],
        of line: WallLine,
        in layout: Layout
    ) -> [WallSpan] {
        let edgeLen = line.length
        guard edgeLen > 1e-4 else { return [] }
        let start = line.start
        let dir = line.direction

        var doorCuts: [DoorCut] = []
        for object in layout.objects where object.kind == .door {
            if let host = DoorHosting.nearestHost(to: object.placement.center, in: layout, reach: doorReachM),
               isSameEdge(hostStart: host.start, hostEnd: host.end, edgeStart: start, edgeEnd: line.end) {
                let toCenter = object.placement.center - start
                let centerT = dot(toCenter, dir)
                let halfW = object.placement.sizeM.x / 2.0
                let startT = min(max(centerT - halfW, 0.0), edgeLen)
                let endT = min(max(centerT + halfW, 0.0), edgeLen)
                if endT - startT > 1e-4 {
                    doorCuts.append(DoorCut(start: startT, end: endT, height: object.heightM ?? lintelM))
                }
            }
        }
        doorCuts.sort { $0.start < $1.start }

        return intervals.flatMap { buildSpans(interval: $0, doors: doorCuts, wall: line) }
    }

    private static func buildSpans(
        interval: (Double, Double),
        doors: [DoorCut],
        wall: WallLine
    ) -> [WallSpan] {
        func span(from fromT: Double, to toT: Double, bottom: Double) -> WallSpan {
            WallSpan(
                start: wall.start + wall.direction * fromT,
                end: wall.start + wall.direction * toT,
                bottom: bottom,
                top: wall.top,
                thickness: wall.thickness
            )
        }

        var result: [WallSpan] = []
        var currentT = interval.0

        let relevantDoors = doors.filter { $0.end > interval.0 && $0.start < interval.1 }
        for door in relevantDoors {
            let doorStart = max(door.start, interval.0)
            let doorEnd = min(door.end, interval.1)

            if doorStart - currentT > 1e-4 {
                result.append(span(from: currentT, to: doorStart, bottom: 0.0))
            }
            if doorEnd - doorStart > 1e-4 {
                result.append(span(from: doorStart, to: doorEnd, bottom: min(door.height, wall.top - 0.1)))
            }
            currentT = max(currentT, doorEnd)
        }

        if interval.1 - currentT > 1e-4 {
            result.append(span(from: currentT, to: interval.1, bottom: 0.0))
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
