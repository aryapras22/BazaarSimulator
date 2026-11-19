import SwiftUI

struct LayoutInspectorColumn: View {
    @Bindable var viewModel: LayoutEditorViewModel
    let onFocusIssue: (LayoutIssue) -> Void

    var body: some View {
        if let selected = viewModel.selectedObject,
           viewModel.inspectorDraft != nil {
            singleObjectInspector(for: selected)
        } else if viewModel.groupSelection != nil {
            groupInspector
        } else {
            nothingSelected
        }
    }

    // MARK: One element

    private func singleObjectInspector(for selected: LayoutObject) -> some View {
        let kind = viewModel.inspectorDraft?.kind ?? selected.kind
        let draftBinding = Binding<InspectorDraft>(
            get: { viewModel.inspectorDraft ?? InspectorDraft(object: selected) },
            set: { viewModel.updateInspectorDraft($0) }
        )

        return InspectorPanel(
            title: viewModel.inspectorTitle,
            editableName: viewModel.inspectorEditableName,
            onRename: { viewModel.renameSelected(to: $0) },
            content: {
                singleObjectFields(for: selected, kind: kind, draft: draftBinding)
            },
            footer: {
                singleObjectFooter(for: selected, kind: kind)
            }
        )
    }

    @ViewBuilder
    private func singleObjectFields(
        for selected: LayoutObject,
        kind: LayoutObjectKind,
        draft: Binding<InspectorDraft>
    ) -> some View {
        // What is wrong with the selection is told at the bottom of the panel, not inside the fields.
        switch kind {
        case .booth:
            BoothInspector(
                draft: draft,
                categories: viewModel.categoryOptions,
                sizeRange: viewModel.sizeRangeM,
                groupActions: viewModel.boothGroupActions(for: selected)
            )
        case .door:
            DoorInspector(
                draft: draft,
                widthRange: viewModel.sizeRangeM,
                advice: nil,
                onUseAdvice: {}
            )
        case .table:
            TableInspector(draft: draft)
        case .seating:
            SeatingInspector(draft: draft)
        case .wall:
            WallInspector(
                draft: draft,
                lengthRange: viewModel.sizeRangeM
            )
        default:
            GenericInspector(
                draft: draft,
                fields: .forObject(selected, kind: kind),
                categories: viewModel.categoryOptions,
                sizeRange: viewModel.sizeRangeM
            )
        }
    }

    @ViewBuilder
    private func singleObjectFooter(for selected: LayoutObject, kind: LayoutObjectKind) -> some View {
        selectionNotes(for: selected)

        if let advice = viewModel.currentDoorAdvice, kind == .door {
            InspectorTip(
                message: advice.message,
                actionTitle: advice.actionTitle,
                onAction: { viewModel.applyDoorAdvice() }
            )
        }

        DeleteSelectionButton(title: "Delete \(kind.displayName.lowercased())") {
            viewModel.deleteSelected()
        }

        SaveChangesButton(isEnabled: viewModel.isInspectorDraftValid) { viewModel.saveChanges() }
    }

    /// The validation messages that name this element, errors first.
    @ViewBuilder
    private func selectionNotes(for selected: LayoutObject) -> some View {
        let related = viewModel.issues.filter { $0.objectIDs.contains(selected.id) }
        let ordered = related.filter { $0.severity == .error } + related.filter { $0.severity == .warning }
        if !ordered.isEmpty {
            InspectorNotes(messages: ordered.map { (text: $0.message, isError: $0.severity == .error) })
        }
    }

    // MARK: Several elements

    private var groupInspector: some View {
        let draftBinding = Binding<GroupInspectorDraft>(
            get: { viewModel.groupDraft ?? GroupInspectorDraft(memberIDs: []) },
            set: { viewModel.updateGroupDraft($0) }
        )
        let isBoothGroup = viewModel.activeLayer == .booths
        return InspectorPanel(title: viewModel.groupSelectionTitle) {
            if isBoothGroup {
                GroupInspector(
                    draft: draftBinding,
                    display: viewModel.groupInspectorDisplay,
                    categories: viewModel.categoryOptions,
                    sizeRange: viewModel.groupSizeRangeM,
                    onResetOpenSides: { viewModel.resetOpenSidesForGroup() }
                )
            } else {
                Text("Drag-select or shift-click to add more. Press Delete to remove them.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        } footer: {
            let noun = isBoothGroup ? "booths" : "objects"
            DeleteSelectionButton(title: "Delete \(viewModel.groupSelection?.memberIDs.count ?? 0) \(noun)") {
                viewModel.requestDeleteGroup()
            }

            SaveChangesButton(isEnabled: viewModel.isInspectorDraftValid) { viewModel.saveChanges() }
        }
    }

    // MARK: Nothing selected

    /// The empty panel: a line asking to pick something, and in the bottom half the validation of the whole layout.
    private var nothingSelected: some View {
        InspectorSurface {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: Spacing.xs) {
                    Text("Nothing Selected here")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Select an element to edit.")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                    if let layout = viewModel.activeLayout {
                        Text(layoutSummary(layout))
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textSecondary.opacity(0.8))
                            .padding(.top, Spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                validationSection
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
            }
        }
    }

    private func layoutSummary(_ layout: Layout) -> String {
        let width = DimensionInput.text(for: layout.sizeM.x)
        let length = DimensionInput.text(for: layout.sizeM.y)
        let booths = layout.objects.filter { $0.kind == .booth }.count
        let doors = layout.objects.filter { $0.kind == .door }.count
        return "\(width) × \(length) m · \(booths) booths · \(doors) doors"
    }

    @ViewBuilder
    private var validationSection: some View {
        if !viewModel.issues.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Validation")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Palette.textSecondary)
                ScrollView(.vertical, showsIndicators: false) {
                    ValidationIssueList(issues: viewModel.issues, onFocus: onFocusIssue)
                }
                .frame(maxHeight: 220)
            }
        }
    }
}

#Preview("Nothing Selected") {
    let session = ProjectSession()
    let project = session.createProject(named: "Market")
    let layout = PreviewLayouts.smallMarket()
    session.setDraft(
        ProjectDraft(name: "Market", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
        for: project.id
    )
    let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
    return LayoutInspectorColumn(viewModel: viewModel, onFocusIssue: { _ in })
        .frame(height: 600)
        .preferredColorScheme(.dark)
}

#Preview("Booth Selected") {
    let session = ProjectSession()
    let project = session.createProject(named: "Market")
    let layout = PreviewLayouts.smallMarket()
    session.setDraft(
        ProjectDraft(name: "Market", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
        for: project.id
    )
    let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
    viewModel.selectObject(layout.objects.first { $0.kind == .booth }?.id)
    return LayoutInspectorColumn(viewModel: viewModel, onFocusIssue: { _ in })
        .frame(height: 600)
        .preferredColorScheme(.dark)
}
