import SwiftUI

extension LayoutEditorView {
    @ViewBuilder
    func inspectorView(for selected: LayoutObject) -> some View {
        let draftBinding = Binding<InspectorDraft>(
            get: { viewModel.inspectorDraft ?? InspectorDraft(object: selected) },
            set: { viewModel.inspectorDraft = $0 }
        )

        InspectorPanel(title: viewModel.inspectorTitle) {
            switch selected.kind {
            case .booth:
                BoothInspector(
                    draft: draftBinding,
                    categories: viewModel.categoryOptions,
                    sizeRange: viewModel.sizeRangeM,
                    titleIssues: viewModel.selectedTitleIssues,
                    openSideIssues: viewModel.selectedOpenSideIssues,
                    groupActions: viewModel.boothGroupActions(for: selected)
                )
            case .door:
                DoorInspector(
                    draft: draftBinding,
                    widthRange: viewModel.sizeRangeM,
                    advice: viewModel.currentDoorAdvice,
                    onUseAdvice: { viewModel.applyDoorAdvice() }
                )
            default:
                GenericInspector(
                    draft: draftBinding,
                    fields: .forKind(selected.kind),
                    sizeRange: viewModel.sizeRangeM,
                    titleIssues: viewModel.selectedTitleIssues
                )
            }
        } footer: {
            Button("Save Changes") {
                viewModel.saveInspectorChanges()
            }
            .buttonStyle(InspectorSaveButtonStyle())
            .disabled(!viewModel.isSaveChangesEnabled)
        }
    }

    func groupInspectorView() -> some View {
        let draftBinding = Binding<GroupInspectorDraft>(
            get: { viewModel.groupDraft ?? GroupInspectorDraft(memberIDs: []) },
            set: { viewModel.groupDraft = $0 }
        )
        return InspectorPanel(title: viewModel.groupSelectionTitle) {
            GroupInspector(
                draft: draftBinding,
                display: viewModel.groupInspectorDisplay,
                categories: viewModel.categoryOptions,
                sizeRange: viewModel.groupSizeRangeM,
                onResetOpenSides: { viewModel.resetOpenSidesForGroup() }
            )
        } footer: {
            VStack(spacing: Spacing.s) {
                Button("Delete \(viewModel.groupSelection?.memberIDs.count ?? 0) booths", role: .destructive) {
                    viewModel.requestDeleteGroup()
                }
                .buttonStyle(.plain)
                .font(Typography.body)
                .foregroundStyle(Palette.destructive)

                Button("Save Changes") {
                    viewModel.saveInspectorChanges()
                }
                .buttonStyle(InspectorSaveButtonStyle())
                .disabled(!viewModel.isSaveChangesEnabled)
            }
        }
    }

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
