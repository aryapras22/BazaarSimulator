import Foundation

enum DoorFlowAdvisor {
    static func advice(for door: LayoutObject, in layout: Layout) -> DoorAdvice? {
        guard door.kind == .door, let flow = door.doorFlow else { return nil }
        let peers = layout.objects.filter {
            $0.kind == .door && $0.doorFlow?.connection == flow.connection
        }
        guard !peers.isEmpty else { return nil }

        let doorLabel = displayLabel(for: door)

        let hasEntry = peers.contains { $0.doorFlow?.direction.allowsEntry == true }
        if !hasEntry {
            return DoorAdviceText.noEntry(doorLabel: doorLabel)
        }

        let hasExit = peers.contains { $0.doorFlow?.direction.allowsExit == true }
        if !hasExit {
            return DoorAdviceText.noExit(doorLabel: doorLabel)
        }

        let maxPeerWidth = peers.map(\.placement.sizeM.x).max() ?? 0
        if flow.direction == .disabled && peers.count > 1 && door.placement.sizeM.x >= maxPeerWidth - 1e-6 {
            return DoorAdviceText.widestDisabled(doorLabel: doorLabel)
        }

        let hasEntranceOnly = peers.contains { $0.doorFlow?.direction == .entrance }
        if flow.direction == .both,
           !hasEntranceOnly,
           let exitOnlyPeer = peers.first(where: { $0.id != door.id && $0.doorFlow?.direction == .exit }) {
            return DoorAdviceText.pairWithExitOnly(
                otherDoorLabel: displayLabel(for: exitOnlyPeer),
                selectedDoorLabel: doorLabel
            )
        }

        return nil
    }

    private static func displayLabel(for door: LayoutObject) -> String {
        let trimmed = door.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Door" : trimmed
    }
}
