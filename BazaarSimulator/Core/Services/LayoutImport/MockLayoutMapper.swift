import Foundation
import simd

enum MockLayoutMapper {
    private static let outerDoorThicknessM = 0.3

    static func layout(
        from dto: BazaarLayoutDTO,
        legend: Legend,
        id: UUID = UUID(),
        nameOverride: String? = nil
    ) -> Layout {
        var objects: [LayoutObject] = []
        objects.append(mapLobbyWall(from: dto.wall))
        objects.append(contentsOf: mapHallDoors(from: dto.doors))
        objects.append(contentsOf: mapOuterDoors(from: dto.outerDoors, gates: dto.gates, exitPt: dto.exitPt))
        objects.append(contentsOf: mapTables(from: dto.tables))
        objects.append(mapStage(from: dto.stage))
        objects.append(mapAudienceArea(from: dto))
        objects.append(contentsOf: mapColumns(from: dto.columns))
        objects.append(contentsOf: mapPilasters(from: dto.pilasters))
        objects.append(contentsOf: mapFixtures(from: dto.fixtures))
        objects.append(contentsOf: mapClosedAreas(from: dto.closed))
        objects.append(contentsOf: mapInitialBooths(from: dto.booths, legend: legend))

        var draftLayout = Layout(
            id: id,
            name: nameOverride ?? dto.meta.name,
            sizeM: SIMD2<Double>(dto.meta.world.width, dto.meta.world.height),
            hall: dto.hall.compactMap { Self.point(from: $0) },
            lobby: dto.lobby.compactMap { Self.point(from: $0) },
            objects: objects,
            markers: mapMarkers(from: dto),
            zones: mapZones(from: dto),
            source: LayoutSource(name: dto.meta.name, sheet: dto.meta.sheet, note: dto.meta.note ?? "")
        )

        for index in draftLayout.objects.indices where draftLayout.objects[index].kind == .booth {
            let booth = draftLayout.objects[index]
            draftLayout.objects[index].openSides = OpenSideInference.infer(for: booth, in: draftLayout)
        }

        return draftLayout
    }

    static func placement(from rect: BazaarRectDTO) -> Placement {
        placement(minX: rect.minX, maxX: rect.maxX, minY: rect.minY, maxY: rect.maxY)
    }

    private static func placement(minX: Double, maxX: Double, minY: Double, maxY: Double) -> Placement {
        Placement(
            center: SIMD2<Double>((minX + maxX) / 2.0, (minY + maxY) / 2.0),
            sizeM: SIMD2<Double>(maxX - minX, maxY - minY)
        )
    }

    private static func point(from coords: [Double]) -> SIMD2<Double>? {
        coords.count >= 2 ? SIMD2<Double>(coords[0], coords[1]) : nil
    }

    private static func mapLobbyWall(from wall: BazaarRectDTO) -> LayoutObject {
        LayoutObject(kind: .wall, label: "Lobby wall", placement: placement(from: wall), reviewState: .detected)
    }

    private static func mapHallDoors(from doors: [BazaarDoorDTO]) -> [LayoutObject] {
        doors.map { door in
            let direction: DoorDirection = door.role.lowercased() == "entrance" ? .entrance : .both
            let doorPlacement = placement(minX: door.minX, maxX: door.maxX, minY: door.minY, maxY: door.maxY)
            return LayoutObject(
                kind: .door,
                label: door.id,
                placement: doorPlacement,
                doorFlow: DoorFlow(direction: direction, connection: .hallToLobby),
                reviewState: .detected
            )
        }
    }

    private static func mapOuterDoors(
        from outerDoors: [BazaarOuterDoorDTO],
        gates: [BazaarMarkerDTO],
        exitPt: BazaarMarkerDTO
    ) -> [LayoutObject] {
        let gatePoint = gates.first.map { SIMD2<Double>($0.posX, $0.posY) }
        let exitPoint = SIMD2<Double>(exitPt.posX, exitPt.posY)
        let centers = outerDoors.map { SIMD2<Double>($0.posX, ($0.minY + $0.maxY) / 2.0) }

        let nearestToGateIndex = gatePoint.flatMap { nearestIndex(to: $0, in: centers) }
        let nearestToExitIndex = nearestIndex(to: exitPoint, in: centers)

        return outerDoors.enumerated().map { index, door in
            let direction: DoorDirection
            if index == nearestToGateIndex {
                direction = .entrance
            } else if index == nearestToExitIndex {
                direction = .exit
            } else {
                direction = .both
            }
            return LayoutObject(
                kind: .door,
                label: "Outer Door \(index + 1)",
                placement: Placement(
                    center: centers[index],
                    sizeM: SIMD2<Double>(door.maxY - door.minY, outerDoorThicknessM),
                    rotationRadians: .pi / 2
                ),
                doorFlow: DoorFlow(direction: direction, connection: .lobbyToOutside),
                reviewState: .detected
            )
        }
    }

    private static func nearestIndex(to target: SIMD2<Double>, in points: [SIMD2<Double>]) -> Int? {
        points.enumerated().min {
            simd_distance_squared($0.element, target) < simd_distance_squared($1.element, target)
        }?.offset
    }

    private static func mapInitialBooths(from booths: [BazaarBoothDTO], legend: Legend) -> [LayoutObject] {
        booths.map { booth in
            LayoutObject(
                kind: .booth,
                label: booth.id,
                placement: Placement(
                    center: SIMD2<Double>(booth.centerX, booth.centerY),
                    sizeM: SIMD2<Double>(booth.width, booth.height)
                ),
                categoryID: CategoryMatcher.entry(for: booth.type, in: legend),
                reviewState: .detected
            )
        }
    }

    private static func mapTables(from tables: [BazaarTableDTO]) -> [LayoutObject] {
        tables.enumerated().map { index, table in
            LayoutObject(
                kind: .table,
                label: "T\(index + 1)",
                placement: Placement(
                    center: SIMD2<Double>(table.centerX, table.centerY),
                    sizeM: SIMD2<Double>(table.width, table.height)
                ),
                reviewState: .detected
            )
        }
    }

    private static func mapStage(from stage: BazaarStageDTO) -> LayoutObject {
        let stagePlacement = placement(minX: stage.minX, maxX: stage.maxX, minY: stage.minY, maxY: stage.maxY)
        return LayoutObject(
            kind: .stage,
            label: "Stage",
            placement: stagePlacement,
            openSides: stageFace(from: stage.face),
            reviewState: .detected
        )
    }

    private static func stageFace(from face: String) -> OpenSides {
        switch face {
        case "x0": return .left
        case "x1": return .right
        case "y0": return .top
        case "y1": return .bottom
        default: return .bottom
        }
    }

    private static func mapAudienceArea(from dto: BazaarLayoutDTO) -> LayoutObject {
        LayoutObject(
            kind: .audienceArea,
            label: dto.kidsLabel ?? "Kids area",
            placement: placement(from: dto.kids),
            reviewState: .detected
        )
    }

    private static func mapColumns(from columns: [BazaarColumnDTO]) -> [LayoutObject] {
        columns.enumerated().map { index, column in
            LayoutObject(
                kind: .pillar,
                label: "P\(index + 1)",
                placement: Placement(
                    center: SIMD2<Double>(column.posX, column.posY),
                    sizeM: SIMD2<Double>(column.diameter, column.diameter)
                ),
                reviewState: .detected
            )
        }
    }

    private static func mapPilasters(from pilasters: [BazaarPilasterDTO]) -> [LayoutObject] {
        pilasters.map { pilaster in
            let kind: LayoutObjectKind
            switch pilaster.kind.lowercased() {
            case "rail": kind = .rail
            case "block": kind = .block
            default: kind = .wall
            }
            let pilasterPlacement = placement(
                minX: pilaster.minX,
                maxX: pilaster.maxX,
                minY: pilaster.minY,
                maxY: pilaster.maxY
            )
            return LayoutObject(
                kind: kind,
                label: kind.displayName,
                placement: pilasterPlacement,
                reviewState: .detected
            )
        }
    }

    private static func mapFixtures(from fixtures: [BazaarFixtureDTO]) -> [LayoutObject] {
        fixtures.map { fixture in
            let kind: LayoutObjectKind = fixture.kind.lowercased() == "stage" ? .stage : .fixture
            let fixturePlacement = placement(
                minX: fixture.minX,
                maxX: fixture.maxX,
                minY: fixture.minY,
                maxY: fixture.maxY
            )
            return LayoutObject(
                kind: kind,
                label: fixture.label,
                placement: fixturePlacement,
                reviewState: .detected
            )
        }
    }

    private static func mapClosedAreas(from closedAreas: [BazaarRectDTO]) -> [LayoutObject] {
        closedAreas.map { rect in
            LayoutObject(
                kind: .closedArea,
                label: "Closed area",
                placement: placement(from: rect),
                reviewState: .detected
            )
        }
    }

    private static func mapMarkers(from dto: BazaarLayoutDTO) -> [LayoutMarker] {
        var markers = dto.gates.map {
            LayoutMarker(kind: .spawn, label: $0.id, position: SIMD2<Double>($0.posX, $0.posY))
        }
        markers.append(
            LayoutMarker(
                kind: .exit,
                label: dto.exitPt.id,
                position: SIMD2<Double>(dto.exitPt.posX, dto.exitPt.posY)
            )
        )
        return markers
    }

    private static func mapZones(from dto: BazaarLayoutDTO) -> [LayoutZone] {
        var zones: [LayoutZone] = []
        if let foyer = dto.foyer, let pos = point(from: foyer.label) {
            zones.append(LayoutZone(label: "FOYER", minX: foyer.minX, maxX: foyer.maxX, labelPosition: pos))
        }
        if let corridor = dto.corridor, let pos = point(from: corridor.label) {
            zones.append(LayoutZone(label: "CORRIDOR", minX: corridor.minX, maxX: corridor.maxX, labelPosition: pos))
        }
        return zones
    }
}
