import SwiftUI

extension LayoutEditorView {
    var groupDeleteDialogTitle: String {
        "Delete \(viewModel.pendingGroupDelete ?? 0) booths?"
    }

    var isGroupDeletePending: Binding<Bool> {
        Binding(
            get: { viewModel.pendingGroupDelete != nil },
            set: { if !$0 { viewModel.pendingGroupDelete = nil } }
        )
    }
}
