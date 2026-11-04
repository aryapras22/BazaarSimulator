import Foundation

struct InspectorDraft: Sendable, Equatable {
    var objectID: UUID
    var kind: LayoutObjectKind
    var label: String
    var widthM: Double
    var lengthM: Double
    var heightM: Double
    var rotationDegrees: Int
    var categoryID: LegendEntry.ID?
    var openSides: OpenSides
    var doorDirection: DoorDirection
    var doorConnection: DoorConnection

    init(object: LayoutObject) {
        self.objectID = object.id
        self.kind = object.kind
        self.label = object.label
        self.widthM = object.placement.sizeM.x
        self.lengthM = object.placement.sizeM.y
        self.heightM = object.heightM ?? Self.defaultHeight(for: object)
        self.rotationDegrees = object.placement.rotationDegrees
        self.categoryID = object.categoryID
        self.openSides = object.openSides
        self.doorDirection = object.doorFlow?.direction ?? .both
        self.doorConnection = object.doorFlow?.connection ?? .hallToLobby
    }

    static func defaultHeight(for object: LayoutObject) -> Double {
        if let catalogID = object.catalogID, let item = ObjectCatalog.item(catalogID) {
            return item.heightM
        }
        let heights: [LayoutObjectKind: Double] = [
            .wall: 3.0, .pillar: 3.0, .booth: 2.4, .door: 2.1,
            .rail: 1.0, .block: 1.2, .fixture: 1.2, .stage: 0.8,
            .table: 0.75, .closedArea: 0.05
        ]
        return heights[object.kind] ?? 3.0
    }

    func applied(to original: LayoutObject) -> LayoutObject {
        var updated = original
        updated.label = label
        if kind == .pillar {
            updated.placement.sizeM = .init(widthM, widthM)
        } else if kind == .door {
            updated.placement.sizeM = .init(widthM, original.placement.sizeM.y)
        } else {
            updated.placement.sizeM = .init(widthM, lengthM)
        }
        if updated.placement.rotationDegrees != rotationDegrees {
            updated.placement.rotationDegrees = rotationDegrees
        }
        updated.categoryID = categoryID
        updated.openSides = openSides
        updated.heightM = heightM
        if kind == .door {
            updated.doorFlow = DoorFlow(direction: doorDirection, connection: doorConnection)
        }
        return updated
    }
}
