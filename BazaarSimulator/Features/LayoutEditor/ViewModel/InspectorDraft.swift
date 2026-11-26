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
    var boothType: BoothType?
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
        self.boothType = object.boothType
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
        return defaultHeight(for: object.kind)
    }

    private static func defaultHeight(for kind: LayoutObjectKind) -> Double {
        let heights: [LayoutObjectKind: Double] = [
            .wall: 3.0, .booth: 2.4, .door: 2.1, .block: 1.2, .closedArea: 0.05, .seating: FurnitureModels.chairHeightM
        ]
        return heights[kind] ?? 3.0
    }

    var categoryChoice: CategoryChoice {
        switch kind {
        case .entertainment:
            return .entertainment(EntertainmentType.resolve(catalogID: catalogID, label: label))
        default:
            return .booth(boothType)
        }
    }

    mutating func choose(_ choice: CategoryChoice) {
        guard kind == .booth || kind == .entertainment else { return }
        switch choice {
        case .booth(let type):
            if kind != .booth {
                catalogID = nil
                heightM = Self.defaultHeight(for: .booth)
            }
            kind = .booth
            boothType = type
            isDisabled = false
        case .entertainment(let type):
            if kind != .entertainment {
                attractiveness = LayoutObjectKind.entertainment.defaultAttractiveness
            }
            kind = .entertainment
            boothType = nil
            catalogID = type.catalogID
            isDisabled = (type == .disabled)
            if let itemHeight = ObjectCatalog.item(type.catalogID)?.heightM {
                heightM = itemHeight
            }
        }
    }

    /// Switches a table or seating draft to the given furniture type. Returns whether the draft changed.
    mutating func convertFurniture(to catalogID: String) -> Bool {
        guard kind == .seating || kind == .table else { return false }
        let before = self
        if catalogID == FurnitureModels.seatingBlockID {
            guard kind != .seating || self.catalogID != FurnitureModels.seatingBlockID else { return false }
            kind = .seating
            self.catalogID = FurnitureModels.seatingBlockID
            widthM = FurnitureModels.seatingBlockSizeM.x
            lengthM = FurnitureModels.seatingBlockSizeM.y
            heightM = FurnitureModels.chairHeightM
        } else if let table = FurnitureModels.table(catalogID) {
            kind = .table
            self.catalogID = table.id
            widthM = table.sizeM.x
            lengthM = table.sizeM.y
            heightM = FurnitureModels.tableHeightM
        }
        return self != before
    }

    func applied(to original: LayoutObject) -> LayoutObject {
        var updated = original
        updated.kind = kind
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
        updated.boothType = boothType
        if kind == .entertainment {
            updated.categoryID = nil
        }
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
