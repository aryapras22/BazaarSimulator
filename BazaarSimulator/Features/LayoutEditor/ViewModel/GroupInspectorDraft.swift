import Foundation

enum FieldChange<Value: Equatable & Sendable>: Equatable, Sendable {
    case unchanged
    case set(Value)
}

enum MixedValue<Value: Equatable & Sendable>: Equatable, Sendable {
    case shared(Value)
    case mixed

    init(_ values: [Value]) {
        guard let first = values.first else {
            self = .mixed
            return
        }
        self = values.allSatisfy { $0 == first } ? .shared(first) : .mixed
    }
}

struct GroupInspectorDraft: Equatable, Sendable {
    let memberIDs: [UUID]
    var category: FieldChange<BoothType?> = .unchanged
    var widthM: FieldChange<Double> = .unchanged
    var lengthM: FieldChange<Double> = .unchanged
    var rotationDegrees: FieldChange<Int> = .unchanged
    var furnitureType: FieldChange<String> = .unchanged

    var hasChanges: Bool {
        category != .unchanged || widthM != .unchanged || lengthM != .unchanged
            || rotationDegrees != .unchanged || furnitureType != .unchanged
    }

    func applied(to member: LayoutObject) -> LayoutObject {
        var updated = member
        if case .set(let catalogID) = furnitureType, member.kind == .table || member.kind == .seating {
            var converted = InspectorDraft(object: member)
            if converted.convertFurniture(to: catalogID) { updated = converted.applied(to: member) }
        }
        if case .set(let value) = category, member.kind.hasCategory { updated.boothType = value }
        if case .set(let value) = widthM, member.kind.isResizable { updated.placement.sizeM.x = value }
        if case .set(let value) = lengthM, member.kind.isResizable { updated.placement.sizeM.y = value }
        if case .set(let value) = rotationDegrees { updated.placement.rotationDegrees = value }
        return updated
    }
}

struct GroupInspectorDisplay: Equatable, Sendable {
    let category: MixedValue<BoothType?>
    let width: MixedValue<Double>
    let length: MixedValue<Double>
    let rotation: MixedValue<Int>
    let warningSummary: String?
    let memberCount: Int
    let boothCount: Int
    let furnitureType: MixedValue<String>
    let furnitureCount: Int

    init(
        category: MixedValue<BoothType?>,
        width: MixedValue<Double>,
        length: MixedValue<Double>,
        rotation: MixedValue<Int>,
        warningSummary: String?,
        memberCount: Int,
        boothCount: Int? = nil,
        furnitureType: MixedValue<String> = .mixed,
        furnitureCount: Int = 0
    ) {
        self.furnitureType = furnitureType
        self.furnitureCount = furnitureCount
        self.category = category
        self.width = width
        self.length = length
        self.rotation = rotation
        self.warningSummary = warningSummary
        self.memberCount = memberCount
        self.boothCount = boothCount ?? memberCount
    }
}
