import Foundation

struct InspectorDraft: Sendable, Equatable {
    var objectID: UUID
    var kind: LayoutObjectKind
    var label: String
    var widthM: Double
    var lengthM: Double
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
        self.rotationDegrees = object.placement.rotationDegrees
        self.categoryID = object.categoryID
        self.openSides = object.openSides
        self.doorDirection = object.doorFlow?.direction ?? .both
        self.doorConnection = object.doorFlow?.connection ?? .hallToLobby
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
        updated.placement.rotationDegrees = rotationDegrees
        updated.categoryID = categoryID
        updated.openSides = openSides
        if kind == .door {
            updated.doorFlow = DoorFlow(direction: doorDirection, connection: doorConnection)
        }
        return updated
    }
}
