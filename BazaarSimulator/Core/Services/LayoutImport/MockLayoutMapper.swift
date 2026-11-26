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
        if let wall = dto.wall {
            objects.append(mapLobbyWall(from: wall))
        }
        objects.append(contentsOf: mapHallDoors(from: dto.doors))
        objects.append(contentsOf: mapOuterDoors(from: dto.outerDoors, gates: dto.gates, exitPt: dto.exitPt))
        if let stage = dto.stage {
            objects.append(mapStage(from: stage))
        }
        objects.append(contentsOf: mapTables(from: dto.tables))
        if let kids = dto.kids, dto.kidsSeats != false {
            objects.append(mapAudienceSeating(from: kids))
        }
        objects.append(contentsOf: mapPilasters(from: dto.pilasters))
        objects.append(contentsOf: mapFixtures(from: dto.fixtures))
        objects.append(contentsOf: mapColumns(from: dto.columns))
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

        for index in draftLayout.objects.indices where draftLayout.objects[index].kind.hasOpenSides {
            let booth = draftLayout.objects[index]
            draftLayout.objects[index].openSides = OpenSideInference.defaultSide(for: booth, in: draftLayout)
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

    /// Walls and doors run along their x axis, so a rect taller than it is wide becomes a quarter-turned placement.
    private static func linearPlacement(minX: Double, maxX: Double, minY: Double, maxY: Double) -> Placement {
        let upright = placement(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
        guard upright.sizeM.y > upright.sizeM.x else { return upright }
        return Placement(
            center: upright.center,
            sizeM: SIMD2<Double>(upright.sizeM.y, upright.sizeM.x),
            rotationRadians: .pi / 2
        )
    }

    /// A box from the file, turned by `rot` degrees and made round when its `shape` says so.
    private static func shapedPlacement(from rect: BazaarRectDTO) -> Placement {
        var shaped = placement(from: rect)
        shaped.rotationRadians = (rect.rotationDegrees ?? 0) * .pi / 180
        shaped.shape = rect.shape?.lowercased() == "round" ? .round : .rect
        return shaped
    }

    private static func point(from coords: [Double]) -> SIMD2<Double>? {
        coords.count >= 2 ? SIMD2<Double>(coords[0], coords[1]) : nil
    }

    private static func mapLobbyWall(from wall: BazaarRectDTO) -> LayoutObject {
        LayoutObject(
            kind: .wall,
            label: "Lobby wall",
            placement: linearPlacement(minX: wall.minX, maxX: wall.maxX, minY: wall.minY, maxY: wall.maxY),
            reviewState: .detected
        )
    }

    private static func mapHallDoors(from doors: [BazaarDoorDTO]) -> [LayoutObject] {
        doors.map { door in
            let direction: DoorDirection
            switch door.role.lowercased() {
            case "entrance": direction = .entrance
            case "exit": direction = .exit
            default: direction = .both
            }
            let doorPlacement = linearPlacement(minX: door.minX, maxX: door.maxX, minY: door.minY, maxY: door.maxY)
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
        let categories = CategoryMatcher.defaultCategories(for: booths, in: legend)
        let typesByID = Dictionary(
            uniqueKeysWithValues: legend.entries.compactMap { entry in entry.type.map { (entry.id, $0) } }
        )
        return booths.map { booth in
            let categoryID = categories[booth.id]
            return LayoutObject(
                kind: .booth,
                label: booth.id,
                placement: Placement(
                    center: SIMD2<Double>(booth.centerX, booth.centerY),
                    sizeM: SIMD2<Double>(booth.width, booth.height)
                ),
                categoryID: categoryID,
                boothType: categoryID.flatMap { typesByID[$0] },
                reviewState: .detected
            )
        }
    }
}

extension MockLayoutMapper {
    private static func mapStage(from stage: BazaarStageDTO) -> LayoutObject {
        ObjectCatalog.detectedEntertainment(
            label: "Stage",
            placement: placement(minX: stage.minX, maxX: stage.maxX, minY: stage.minY, maxY: stage.maxY)
        )
    }

    /// A table without a named model is a square dot, so it becomes the round standard table closest in size.
    private static func mapTables(from tables: [BazaarTableDTO]) -> [LayoutObject] {
        let rounds = FurnitureModels.tables.filter { $0.shape == .round }
        return tables.enumerated().map { index, table in
            let closestRound = rounds.min { abs($0.sizeM.x - table.width) < abs($1.sizeM.x - table.width) } ?? rounds[0]
            let model = table.model.flatMap { FurnitureModels.table($0) } ?? closestRound
            var tablePlacement = Placement(center: SIMD2(table.centerX, table.centerY), sizeM: model.sizeM)
            tablePlacement.rotationRadians = (table.rotationDegrees ?? 0) * .pi / 180
            return LayoutObject(
                kind: .table,
                label: "Table \(index + 1)",
                placement: tablePlacement,
                reviewState: .detected,
                catalogID: model.id
            )
        }
    }

    private static func mapAudienceSeating(from area: BazaarRectDTO) -> LayoutObject {
        LayoutObject(
            kind: .seating,
            label: "Audience seating",
            placement: placement(from: area),
            reviewState: .detected,
            catalogID: FurnitureModels.seatingBlockID
        )
    }

    private static func mapPilasters(from pilasters: [BazaarPilasterDTO]) -> [LayoutObject] {
        pilasters.map { pilaster in
            let kind: LayoutObjectKind = pilaster.kind.lowercased() == "wall" ? .wall : .block
            if kind == .wall, let degrees = pilaster.rotationDegrees {
                var turned = placement(minX: pilaster.minX, maxX: pilaster.maxX, minY: pilaster.minY, maxY: pilaster.maxY)
                turned.rotationRadians = degrees * .pi / 180
                return LayoutObject(kind: kind, label: kind.displayName, placement: turned, reviewState: .detected)
            }
            let pilasterPlacement = kind == .wall
                ? linearPlacement(minX: pilaster.minX, maxX: pilaster.maxX, minY: pilaster.minY, maxY: pilaster.maxY)
                : placement(minX: pilaster.minX, maxX: pilaster.maxX, minY: pilaster.minY, maxY: pilaster.maxY)
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
            let fixturePlacement = shapedPlacement(from: BazaarRectDTO(
                minX: fixture.minX,
                maxX: fixture.maxX,
                minY: fixture.minY,
                maxY: fixture.maxY,
                shape: fixture.shape,
                rotationDegrees: fixture.rotationDegrees
            ))
            // A fixture of kind "stage" is a stage extension, whatever its label says.
            if fixture.kind.lowercased() == "stage" || ObjectCatalog.namesEntertainment(fixture.label) {
                return ObjectCatalog.detectedEntertainment(label: fixture.label, placement: fixturePlacement)
            }
            if fixture.kind.lowercased() == "seating" {
                return LayoutObject(
                    kind: .seating,
                    label: fixture.label,
                    placement: fixturePlacement,
                    reviewState: .detected,
                    catalogID: FurnitureModels.seatingBlockID
                )
            }
            return LayoutObject(kind: .block, label: fixture.label, placement: fixturePlacement, reviewState: .detected)
        }
    }

    private static func mapClosedAreas(from closedAreas: [BazaarRectDTO]) -> [LayoutObject] {
        closedAreas.map { rect in
            LayoutObject(
                kind: .closedArea,
                label: "Restricted area",
                placement: shapedPlacement(from: rect),
                reviewState: .detected
            )
        }
    }

    private static func mapColumns(from columns: [BazaarColumnDTO]) -> [LayoutObject] {
        columns.map { column in
            LayoutObject(
                kind: .block,
                label: "Column",
                placement: Placement(
                    center: SIMD2<Double>(column.posX, column.posY),
                    sizeM: SIMD2<Double>(repeating: column.diameter),
                    shape: .round
                ),
                reviewState: .detected,
                catalogID: ObjectCatalog.columnID
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
