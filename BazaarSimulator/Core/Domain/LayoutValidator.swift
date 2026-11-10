import Foundation
import simd

enum LayoutValidator {
    static let overlapToleranceM = 0.1
    static let floorToleranceM = 0.15

    static func issues(in layout: Layout) -> [LayoutIssue] {
        let boundsByID = Dictionary(
            uniqueKeysWithValues: layout.objects.map { ($0.id, LayoutGeometry.bounds(of: $0.placement)) }
        )
        var result: [LayoutIssue] = []
        result.append(contentsOf: checkMinimumSizes(in: layout))
        result.append(contentsOf: checkOverlaps(in: layout, boundsByID: boundsByID))
        result.append(contentsOf: checkFloorBounds(in: layout))
        result.append(contentsOf: checkBoothOpenSides(in: layout, boundsByID: boundsByID))
        result.append(contentsOf: checkHallDoors(in: layout))
        return result
    }

    private static func checkMinimumSizes(in layout: Layout) -> [LayoutIssue] {
        var issues: [LayoutIssue] = []
        for object in layout.objects where object.kind.isResizable {
            let minDim = object.kind.minimumDimensionM
            let isWidthTooSmall = object.placement.sizeM.x < minDim - 1e-6
            let isLengthTooSmall = object.kind != .door
                && object.placement.sizeM.y < minDim - 1e-6
            if isWidthTooSmall || isLengthTooSmall {
                issues.append(
                    LayoutIssue(
                        severity: .error,
                        kind: .belowMinimumSize,
                        objectIDs: [object.id],
                        message: LayoutIssueText.belowMinimumSize
                    )
                )
            }
        }
        return issues
    }

    private static func checkOverlaps(
        in layout: Layout,
        boundsByID: [UUID: BoundingBox]
    ) -> [LayoutIssue] {
        var issues: [LayoutIssue] = []
        let booths = layout.objects.filter { $0.kind == .booth }
        let obstacles = layout.objects.filter { $0.kind.blocksWalking }

        var reportedPairs: Set<Set<UUID>> = []
        for booth in booths {
            guard let boothBox = boundsByID[booth.id] else { continue }
            for other in obstacles where other.id != booth.id {
                guard let otherBox = boundsByID[other.id],
                      !areBoundsApart(boothBox, otherBox, byMoreThan: overlapToleranceM) else {
                    continue
                }
                let pair: Set<UUID> = [booth.id, other.id]
                guard !reportedPairs.contains(pair) else { continue }
                if LayoutGeometry.overlapDepth(booth.placement, other.placement) > overlapToleranceM {
                    reportedPairs.insert(pair)
                    issues.append(
                        LayoutIssue(
                            severity: .warning,
                            kind: .overlappingObjects,
                            objectIDs: [booth.id, other.id],
                            message: LayoutIssueText.overlappingObjects(booth.label, other.label)
                        )
                    )
                }
            }
        }
        return issues
    }

    private static func checkFloorBounds(in layout: Layout) -> [LayoutIssue] {
        let hasWalkable = !layout.hall.isEmpty || !layout.lobby.isEmpty
        guard hasWalkable else { return [] }
        var issues: [LayoutIssue] = []
        // Doors sit in a wall line, which can fall in the gap between hall and lobby or just past their edge.
        for object in layout.objects where object.kind.isMovable && !object.kind.isStructural && object.kind != .door {
            var inset = object.placement
            inset.sizeM = SIMD2<Double>(
                max(0.01, inset.sizeM.x - 2 * floorToleranceM),
                max(0.01, inset.sizeM.y - 2 * floorToleranceM)
            )
            if !LayoutGeometry.isPlacementInsideWalkableFloor(inset, in: layout) {
                issues.append(
                    LayoutIssue(
                        severity: .warning,
                        kind: .outsideFloor,
                        objectIDs: [object.id],
                        message: LayoutIssueText.outsideFloor(object.label)
                    )
                )
            }
        }
        return issues
    }

    private static func checkBoothOpenSides(
        in layout: Layout,
        boundsByID: [UUID: BoundingBox]
    ) -> [LayoutIssue] {
        var issues: [LayoutIssue] = []
        let blockingObjects = layout.objects.filter(\.kind.blocksWalking)
        for booth in layout.objects where booth.kind == .booth {
            if booth.openSides.isEmpty {
                issues.append(
                    LayoutIssue(
                        severity: .warning,
                        kind: .noOpenSides,
                        objectIDs: [booth.id],
                        message: LayoutIssueText.noOpenSides
                    )
                )
                continue
            }

            let boothBox = boundsByID[booth.id] ?? LayoutGeometry.bounds(of: booth.placement)
            let nearby = blockingObjects.filter { candidate in
                guard candidate.id != booth.id,
                      let candidateBox = boundsByID[candidate.id] else {
                    return false
                }
                return !areBoundsApart(
                    boothBox,
                    candidateBox,
                    byMoreThan: OpenSideInference.probeDepthM + overlapToleranceM
                )
            }

            for side in OpenSides.ordered where booth.openSides.contains(side) {
                if !OpenSideInference.isSideOpen(side, of: booth, in: layout, candidates: nearby) {
                    issues.append(
                        LayoutIssue(
                            severity: .warning,
                            kind: .blockedOpenSide(side: side),
                            objectIDs: [booth.id],
                            message: LayoutIssueText.blockedOpenSide(sideName(for: side))
                        )
                    )
                }
            }
        }
        return issues
    }

    private static func areBoundsApart(
        _ first: BoundingBox,
        _ second: BoundingBox,
        byMoreThan margin: Double
    ) -> Bool {
        first.maxX + margin < second.minX
            || second.maxX + margin < first.minX
            || first.maxY + margin < second.minY
            || second.maxY + margin < first.minY
    }

    private static func checkHallDoors(in layout: Layout) -> [LayoutIssue] {
        let hallDoors = layout.objects.filter {
            $0.kind == .door && $0.doorFlow?.connection == .hallToLobby
        }
        guard !hallDoors.isEmpty else { return [] }
        let ids = hallDoors.map(\.id)
        var issues: [LayoutIssue] = []

        if !hallDoors.contains(where: { $0.doorFlow?.direction.allowsEntry == true }) {
            issues.append(
                LayoutIssue(
                    severity: .warning,
                    kind: .missingHallDoorEntry,
                    objectIDs: ids,
                    message: LayoutIssueText.missingHallDoorEntry
                )
            )
        }
        if !hallDoors.contains(where: { $0.doorFlow?.direction.allowsExit == true }) {
            issues.append(
                LayoutIssue(
                    severity: .warning,
                    kind: .missingHallDoorExit,
                    objectIDs: ids,
                    message: LayoutIssueText.missingHallDoorExit
                )
            )
        }
        return issues
    }

    private static func sideName(for side: OpenSides) -> String {
        if side == .top { return "Top" }
        if side == .right { return "Right" }
        if side == .bottom { return "Bottom" }
        return "Left"
    }
}
