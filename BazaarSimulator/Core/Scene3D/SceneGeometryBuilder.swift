import Foundation
import simd

struct SceneMaterialKey: Hashable, Sendable {
    let role: MaterialRole
    let tint: LegendColor?
}

struct SceneGeometry: Sendable {
    var version: Int = 0
    var meshes: [SceneMaterialKey: TriangleMesh]
}

nonisolated enum SceneGeometryBuilder {
    static func build(
        layout: Layout,
        legend: Legend,
        tab: LayoutObjectTab = .floorPlan
    ) -> SceneGeometry {
        var meshes: [SceneMaterialKey: TriangleMesh] = [:]
        appendFloors(from: layout, into: &meshes)
        appendPerimeterWalls(from: layout, into: &meshes)
        appendObjects(from: layout, legend: legend, tab: tab, into: &meshes)
        return SceneGeometry(meshes: meshes)
    }

    private static func appendFloors(
        from layout: Layout,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        var floorMesh = TriangleMesh()
        floorMesh.appendFloorPolygon(layout.hall, heightY: 0.0)
        if !layout.lobby.isEmpty {
            floorMesh.appendFloorPolygon(layout.lobby, heightY: 0.0)
        }
        appendMesh(key: SceneMaterialKey(role: .floor, tint: nil), mesh: floorMesh, into: &meshes)
    }

    private static func appendPerimeterWalls(
        from layout: Layout,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        appendWallSpans(PerimeterWalls.spans(for: layout), into: &meshes)
    }

    private static func appendWallObject(
        _ object: LayoutObject,
        layout: Layout,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        appendWallSpans(PerimeterWalls.spans(forWallObject: object, in: layout), into: &meshes)
    }

    private static func appendWallSpans(
        _ spans: [WallSpan],
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        var wallMesh = TriangleMesh()
        for span in spans {
            let spanVec = span.end - span.start
            let spanLen = length(spanVec)
            guard spanLen > 1e-4 else { continue }
            let mid = (span.start + span.end) / 2.0
            let spanH = span.top - span.bottom
            let centerY = span.bottom + spanH / 2.0
            let yaw = atan2(spanVec.y, spanVec.x)
            wallMesh.appendBox(
                center: SIMD3<Double>(mid.x, centerY, mid.y),
                size: SIMD3<Double>(spanLen, spanH, span.thickness),
                yaw: yaw
            )
        }
        appendMesh(key: SceneMaterialKey(role: .wall, tint: nil), mesh: wallMesh, into: &meshes)
    }

    private static func appendObjects(
        from layout: Layout,
        legend: Legend,
        tab: LayoutObjectTab,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        for object in layout.objects {
            if object.kind == .booth {
                appendBooth(object, legend: legend, tab: tab, into: &meshes)
            } else if object.kind == .door {
                appendDoor(object, tab: tab, into: &meshes)
            } else if object.kind == .wall, object.catalogID == nil || object.catalogID == "wall" {
                appendWallObject(object, layout: layout, into: &meshes)
            } else {
                appendGeneric(object, into: &meshes)
            }
        }
    }

    private static func appendBooth(
        _ object: LayoutObject,
        legend: Legend,
        tab: LayoutObjectTab,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        let primitives = BoothShape.primitives(
            size: object.placement.sizeM,
            openSides: object.openSides ?? []
        )
        let worldOffset = SIMD3<Double>(object.placement.center.x, 0, object.placement.center.y)
        let rotation = object.placement.rotationRadians
        let categoryColor = object.categoryID.flatMap { catID in
            legend.entries.first { $0.id == catID }?.color
        }

        for prim in primitives {
            let worldPrim = prim.rotated(by: rotation).translated(by: worldOffset)
            let key: SceneMaterialKey
            if tab == .flow {
                key = SceneMaterialKey(role: .panel, tint: nil)
            } else if prim.role == MaterialRole.fascia || prim.role == MaterialRole.counter {
                key = SceneMaterialKey(role: prim.role, tint: categoryColor)
            } else {
                key = SceneMaterialKey(role: prim.role, tint: nil)
            }
            appendPrimitive(worldPrim, key: key, into: &meshes)
        }
    }

    private static func appendDoor(
        _ object: LayoutObject,
        tab: LayoutObjectTab,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        let worldOffset = SIMD3<Double>(object.placement.center.x, 0, object.placement.center.y)
        let rotation = object.placement.rotationRadians

        if tab == .flow {
            let arrowLength = min(max(object.placement.sizeM.x * 0.6, 0.6), 1.2)
            let arrowBox = ShapePrimitive.box(
                center: SIMD3<Double>(0, 0.01, 0),
                size: SIMD3<Double>(0.15, 0.02, arrowLength),
                yaw: 0,
                role: .accent
            ).rotated(by: rotation).translated(by: worldOffset)
            appendPrimitive(arrowBox, key: SceneMaterialKey(role: .accent, tint: nil), into: &meshes)
        } else {
            let catalogID = object.catalogID ?? "door"
            let height = object.heightM ?? 2.1
            let primitives = ObjectShapes.shape(for: catalogID, size: object.placement.sizeM, height: height)
            for prim in primitives {
                let worldPrim = prim.rotated(by: rotation).translated(by: worldOffset)
                appendPrimitive(worldPrim, key: SceneMaterialKey(role: prim.role, tint: nil), into: &meshes)
            }
        }
    }

    private static func appendGeneric(
        _ object: LayoutObject,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        let worldOffset = SIMD3<Double>(object.placement.center.x, 0, object.placement.center.y)
        let rotation = object.placement.rotationRadians
        let primitives = primitivesForObject(object)
        for prim in primitives {
            let worldPrim = prim.rotated(by: rotation).translated(by: worldOffset)
            appendPrimitive(worldPrim, key: SceneMaterialKey(role: prim.role, tint: nil), into: &meshes)
        }
    }
}

extension SceneGeometryBuilder {
    private static func appendMesh(
        key: SceneMaterialKey,
        mesh: TriangleMesh,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        if meshes[key] != nil {
            meshes[key]?.append(mesh)
        } else {
            meshes[key] = mesh
        }
    }

    private static func appendPrimitive(
        _ primitive: ShapePrimitive,
        key: SceneMaterialKey,
        into meshes: inout [SceneMaterialKey: TriangleMesh]
    ) {
        var mesh = meshes[key] ?? TriangleMesh()
        switch primitive {
        case let .box(center, size, yaw, _):
            mesh.appendBox(center: center, size: size, yaw: yaw)
        case let .cylinder(center, radius, height, segments, _):
            mesh.appendCylinder(center: center, radius: radius, height: height, segments: segments)
        }
        meshes[key] = mesh
    }

    private static func primitivesForObject(_ object: LayoutObject) -> [ShapePrimitive] {
        let catalogItem = object.catalogID.flatMap(ObjectCatalog.item)
            ?? ObjectCatalog.defaultItemID(for: object.kind).flatMap(ObjectCatalog.item)

        if let catalogItem {
            let height = object.heightM ?? catalogItem.heightM
            return catalogItem.shape(size: object.placement.sizeM, height: height)
        }
        return kindDefaultPrimitives(object)
    }

    private static func kindDefaultPrimitives(_ object: LayoutObject) -> [ShapePrimitive] {
        let size = object.placement.sizeM
        switch object.kind {
        case .wall:
            let wallH = object.heightM ?? 3.0
            return [.box(center: SIMD3(0, wallH / 2.0, 0), size: SIMD3(size.x, wallH, size.y), yaw: 0, role: .wall)]
        case .rail:
            let railH = object.heightM ?? 1.1
            return [.box(center: SIMD3(0, railH / 2.0, 0), size: SIMD3(size.x, railH, size.y), yaw: 0, role: .frame)]
        case .block:
            let blockH = object.heightM ?? 0.8
            return [.box(center: SIMD3(0, blockH / 2.0, 0), size: SIMD3(size.x, blockH, size.y), yaw: 0, role: .slab)]
        case .closedArea:
            let slabH = object.heightM ?? 0.05
            return [.box(center: SIMD3(0, slabH / 2.0, 0), size: SIMD3(size.x, slabH, size.y), yaw: 0, role: .slab)]
        case .pillar:
            let pillarH = object.heightM ?? 3.0
            let rad = min(size.x, size.y) / 2.0
            return [
                .cylinder(center: SIMD3(0, pillarH / 2.0, 0), radius: rad, height: pillarH, segments: 16, role: .pillar)
            ]
        case .stage, .audienceArea:
            let stageH = object.heightM ?? 0.8
            return [.box(center: SIMD3(0, stageH / 2.0, 0), size: SIMD3(size.x, stageH, size.y), yaw: 0, role: .stage)]
        case .table:
            let tableH = object.heightM ?? 0.75
            return ObjectShapes.shape(for: "table-round-4", size: size, height: tableH)
        default:
            let defH = object.heightM ?? 1.0
            return [.box(center: SIMD3(0, defH / 2.0, 0), size: SIMD3(size.x, defH, size.y), yaw: 0, role: .counter)]
        }
    }
}
