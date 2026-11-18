import Foundation
import Observation

/// Edits a draft of the project's `EventParameters`. Nothing reaches the session until `apply()`.
@Observable
@MainActor
final class ParametersViewModel {
    static let maxVisitors = 1_000_000

    let projectID: UUID
    let catalog: PresetCatalog
    private let session: any ProjectSessionProtocol
    private let onClose: () -> Void
    private let onApply: (() -> Void)?

    private(set) var draft: EventParameters

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

    // MARK: Bazaar type and visitor mix

    var bazaarTypeID: String {
        get { draft.bazaarTypeID }
        set { selectBazaarType(id: newValue) }
    }

    func bazaarTypeTitle(for id: String) -> String {
        if id == EventParameters.customBazaarTypeID {
            return EventParameters.customBazaarTypeName
        }
        return catalog.bazaarType(id: id)?.name ?? id
    }

    /// Picking a type reseeds the visitor mix without altering total visitors.
    func selectBazaarType(id: String) {
        guard let preset = catalog.bazaarType(id: id) else { return }
        draft.bazaarTypeID = id
        draft.mix = catalog.mix(for: preset)
    }

    var mix: VisitorMix { draft.mix }

    func setPercent(_ percent: Int, for id: String) {
        let previousPercents = draft.mix.shares.map(\.percent)
        draft.mix.setPercent(percent, for: id)
        if draft.mix.shares.map(\.percent) != previousPercents {
            draft.bazaarTypeID = EventParameters.customBazaarTypeID
        }
    }

    func toggleLock(for id: String) {
        draft.mix.toggleLock(for: id)
    }

    // MARK: Cancel and apply

    func cancel() {
        onClose()
    }

    func apply() {
        session.setEventParameters(draft, for: projectID)
        onClose()
        onApply?()
    }
}
