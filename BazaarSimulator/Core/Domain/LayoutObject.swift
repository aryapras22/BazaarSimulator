import Foundation

enum ReviewState: String, Codable, Hashable, Sendable {
    case detected
    case confirmed
}

struct LayoutObject: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: LayoutObjectKind
    var label: String
    var placement: Placement
    var categoryID: LegendEntry.ID?
    var openSides: OpenSides
    var doorFlow: DoorFlow?
    var reviewState: ReviewState
    var catalogID: String?
    var heightM: Double?
    var attractiveness: Double
    /// A booth that stands in the hall but is closed. It still takes up floor, and no visitor goes to it.
    var isDisabled: Bool

    init(
        id: UUID = UUID(),
        kind: LayoutObjectKind,
        label: String,
        placement: Placement,
        categoryID: LegendEntry.ID? = nil,
        openSides: OpenSides = [],
        doorFlow: DoorFlow? = nil,
        reviewState: ReviewState = .confirmed,
        catalogID: String? = nil,
        heightM: Double? = nil,
        attractiveness: Double? = nil,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.placement = placement
        self.categoryID = categoryID
        self.openSides = openSides
        self.doorFlow = doorFlow
        self.reviewState = reviewState
        self.catalogID = catalogID
        self.heightM = heightM
        self.attractiveness = attractiveness ?? kind.defaultAttractiveness
        self.isDisabled = isDisabled
    }
}

extension LayoutObject {
    /// A column is a round block that needs no title of its own.
    var isColumn: Bool {
        catalogID == ObjectCatalog.columnID
    }
}

extension LayoutObject {
    /// Layouts saved before attractiveness or disabling existed have no value for them, so they read as the default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(LayoutObjectKind.self, forKey: .kind)
        label = try container.decode(String.self, forKey: .label)
        placement = try container.decode(Placement.self, forKey: .placement)
        categoryID = try container.decodeIfPresent(LegendEntry.ID.self, forKey: .categoryID)
        openSides = try container.decode(OpenSides.self, forKey: .openSides)
        doorFlow = try container.decodeIfPresent(DoorFlow.self, forKey: .doorFlow)
        reviewState = try container.decode(ReviewState.self, forKey: .reviewState)
        catalogID = try container.decodeIfPresent(String.self, forKey: .catalogID)
        heightM = try container.decodeIfPresent(Double.self, forKey: .heightM)
        attractiveness = try container.decodeIfPresent(Double.self, forKey: .attractiveness) ?? 1
        isDisabled = try container.decodeIfPresent(Bool.self, forKey: .isDisabled) ?? false
    }
}
