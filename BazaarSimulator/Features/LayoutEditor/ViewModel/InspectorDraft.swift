import Foundation

struct InspectorDraft: Sendable, Equatable {
    var objectID: UUID
    var kind: LayoutObjectKind
    var label: String
    var widthM: Double
    var lengthM: Double
    var heightM: Double
    var rotationDegrees: Int
    var shape: FootprintShape
    var categoryID: LegendEntry.ID?
    var openSides: OpenSides
    var doorDirection: DoorDirection
    var doorConnection: DoorConnection
    var catalogID: String?
    var attractiveness: Double
    var isDisabled: Bool

    init(object: LayoutObject) {
        self.objectID = object.id
        self.kind = object.kind
        self.label = object.label
        self.widthM = object.placement.sizeM.x
        self.lengthM = object.placement.sizeM.y
        self.heightM = object.heightM ?? Self.defaultHeight(for: object)
        self.rotationDegrees = object.placement.rotationDegrees
        self.shape = object.placement.shape
        self.categoryID = object.categoryID
        self.openSides = object.openSides
        self.doorDirection = object.doorFlow?.direction ?? .both
        self.doorConnection = object.doorFlow?.connection ?? .hallToLobby
        self.catalogID = object.catalogID
        self.attractiveness = object.attractiveness
        self.isDisabled = object.isDisabled
    }

    static func defaultHeight(for object: LayoutObject) -> Double {
        if let catalogID = object.catalogID, let item = ObjectCatalog.item(catalogID) {
            return item.heightM
        }
        let heights: [LayoutObjectKind: Double] = [
            .wall: 3.0, .booth: 2.4, .door: 2.1, .block: 1.2, .closedArea: 0.05
        ]
        return heights[object.kind] ?? 3.0
    }

    func applied(to original: LayoutObject) -> LayoutObject {
        var updated = original
        updated.label = label
        if kind == .door {
            updated.placement.sizeM = .init(widthM, original.placement.sizeM.y)
        } else {
            updated.placement.sizeM = .init(widthM, lengthM)
        }
        if updated.placement.rotationDegrees != rotationDegrees {
            updated.placement.rotationDegrees = rotationDegrees
        }
        if kind.canBeRound {
            updated.placement.shape = shape
        }
        updated.categoryID = categoryID
        updated.openSides = openSides
        updated.catalogID = catalogID
        updated.attractiveness = attractiveness
        updated.isDisabled = isDisabled
        if original.heightM != nil || heightM != Self.defaultHeight(for: original) {
            updated.heightM = heightM
        }
        if kind == .door {
            updated.doorFlow = DoorFlow(direction: doorDirection, connection: doorConnection)
        }
        return updated
    }
}
