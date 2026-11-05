import Foundation
import Observation

/// Edits a draft of the project's `EventParameters`. Nothing reaches the session until `apply()`.
@Observable
@MainActor
final class ParametersViewModel {
    static let groupSizeOptions = Array(1...10)
    static let maxVisitors = 1_000_000
    private static let slotLengthMinutes = 120

    let projectID: UUID
    let catalog: PresetCatalog
    private let session: any ProjectSessionProtocol
    private let onClose: () -> Void
    private let onApply: (() -> Void)?

    private(set) var draft: EventParameters
    var isPeakEnabled: Bool
    private(set) var peakSlots: [TimeRange]

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        catalog: PresetCatalog,
        onClose: @escaping () -> Void,
        onApply: (() -> Void)? = nil
    ) {
        self.projectID = projectID
        self.session = session
        self.catalog = catalog
        self.onClose = onClose
        self.onApply = onApply

        let stored = session.eventParameters(for: projectID) ?? catalog.defaultParameters()
        draft = stored
        isPeakEnabled = !stored.peakPeriods.isEmpty
        peakSlots = Self.slots(including: stored.peakPeriods)
    }

    // MARK: Total visitors

    var totalVisitorsText: String { String(draft.totalVisitors) }

    @discardableResult
    func commitTotalVisitors(_ text: String) -> String {
        if let value = Int(text.trimmingCharacters(in: .whitespaces)), value > 0 {
            draft.totalVisitors = min(value, Self.maxVisitors)
        }
        return totalVisitorsText
    }

    // MARK: Event hours

    var startText: String { TimeRange.format(draft.eventHours.startMinute) }
    var endText: String { TimeRange.format(draft.eventHours.endMinute) }

    /// Accepts the text only when the start stays before the end. Returns the text to show.
    @discardableResult
    func commitStart(_ text: String) -> String {
        if let minute = TimeRange.minutes(from: text), minute < draft.eventHours.endMinute {
            draft.eventHours.startMinute = minute
        }
        return startText
    }

    @discardableResult
    func commitEnd(_ text: String) -> String {
        if let minute = TimeRange.minutes(from: text), minute > draft.eventHours.startMinute {
            draft.eventHours.endMinute = minute
        }
        return endText
    }

    // MARK: Peak hours

    func isPeakSelected(_ slot: TimeRange) -> Bool {
        draft.peakPeriods.contains(slot)
    }

    func togglePeak(_ slot: TimeRange) {
        guard isPeakEnabled else { return }
        if let index = draft.peakPeriods.firstIndex(of: slot) {
            draft.peakPeriods.remove(at: index)
        } else {
            draft.peakPeriods.append(slot)
        }
    }

    var canAddPeakSlot: Bool {
        isPeakEnabled && nextSlot != nil
    }

    func addPeakSlot() {
        guard canAddPeakSlot, let slot = nextSlot else { return }
        peakSlots.append(slot)
        draft.peakPeriods.append(slot)
    }

    private var nextSlot: TimeRange? {
        let start = peakSlots.last?.endMinute ?? 0
        let end = start + Self.slotLengthMinutes
        return end <= TimeRange.minutesPerDay ? TimeRange(startMinute: start, endMinute: end) : nil
    }

    private static func slots(including periods: [TimeRange]) -> [TimeRange] {
        var slots = stride(from: 8 * 60, to: 20 * 60, by: slotLengthMinutes).map {
            TimeRange(startMinute: $0, endMinute: $0 + slotLengthMinutes)
        }
        for period in periods where !slots.contains(period) {
            slots.append(period)
        }
        return slots.sorted { $0.startMinute < $1.startMinute }
    }

    // MARK: Bazaar type, visitor mix, group size

    var bazaarTypeID: String {
        get { draft.bazaarTypeID }
        set { selectBazaarType(id: newValue) }
    }

    /// Picking a type reseeds the visitor total and the mix. The user can change both afterwards.
    func selectBazaarType(id: String) {
        guard let preset = catalog.bazaarType(id: id) else { return }
        draft.bazaarTypeID = id
        draft.totalVisitors = preset.totalVisitors
        draft.mix = catalog.mix(for: preset)
    }

    var mix: VisitorMix { draft.mix }

    func setPercent(_ percent: Int, for id: String) {
        draft.mix.setPercent(percent, for: id)
    }

    func toggleLock(for id: String) {
        draft.mix.toggleLock(for: id)
    }

    var groupSize: Int {
        get { draft.groupSize }
        set { draft.groupSize = min(max(newValue, 1), Self.groupSizeOptions.last ?? 1) }
    }

    // MARK: Cancel and apply

    func cancel() {
        onClose()
    }

    func apply() {
        var result = draft
        if !isPeakEnabled {
            result.peakPeriods = []
        } else {
            result.peakPeriods.sort { $0.startMinute < $1.startMinute }
        }
        session.setEventParameters(result, for: projectID)
        onClose()
        onApply?()
    }
}
