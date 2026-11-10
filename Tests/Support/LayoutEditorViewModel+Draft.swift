@testable import BazaarSimulator

extension LayoutEditorViewModel {
    func editInspectorDraft(_ change: (inout InspectorDraft) -> Void) {
        guard var draft = inspectorDraft else { return }
        change(&draft)
        updateInspectorDraft(draft)
    }

    func editGroupDraft(_ change: (inout GroupInspectorDraft) -> Void) {
        guard var draft = groupDraft else { return }
        change(&draft)
        updateGroupDraft(draft)
    }
}
