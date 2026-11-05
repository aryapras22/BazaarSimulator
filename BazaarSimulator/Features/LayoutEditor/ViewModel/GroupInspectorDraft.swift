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
    var category: FieldChange<LegendEntry.ID?> = .unchanged
    var widthM: FieldChange<Double> = .unchanged
    var lengthM: FieldChange<Double> = .unchanged
    var rotationDegrees: FieldChange<Int> = .unchanged
    var chairs: FieldChange<Int> = .unchanged

    var hasChanges: Bool {
        category != .unchanged || widthM != .unchanged || lengthM != .unchanged
            || rotationDegrees != .unchanged || chairs != .unchanged
    }

    func applied(to member: LayoutObject) -> LayoutObject {
        var updated = member
        if case .set(let value) = category { updated.categoryID = value }
        if case .set(let value) = widthM { updated.placement.sizeM.x = value }
        if case .set(let value) = lengthM { updated.placement.sizeM.y = value }
        if case .set(let value) = rotationDegrees { updated.placement.rotationDegrees = value }
        if case .set(let count) = chairs, member.kind == .table {
            updated.catalogID = count == 2 ? "table-2" : "table-4"
        }
        return updated
    }
}

struct GroupInspectorDisplay: Equatable, Sendable {
    let category: MixedValue<LegendEntry.ID?>
    let width: MixedValue<Double>
    let length: MixedValue<Double>
    let rotation: MixedValue<Int>
    let chairs: MixedValue<Int>?
    let warningSummary: String?
    let memberCount: Int
    let boothCount: Int

    init(
        category: MixedValue<LegendEntry.ID?>,
        width: MixedValue<Double>,
        length: MixedValue<Double>,
        rotation: MixedValue<Int>,
        chairs: MixedValue<Int>? = nil,
        warningSummary: String?,
        memberCount: Int,
        boothCount: Int? = nil
    ) {
        self.category = category
        self.width = width
        self.length = length
        self.rotation = rotation
        self.chairs = chairs
        self.warningSummary = warningSummary
        self.memberCount = memberCount
        self.boothCount = boothCount ?? memberCount
    }
}
