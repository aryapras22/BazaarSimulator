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
            layoutInfoInspector
        }
    }

    private func singleObjectInspector(for selected: LayoutObject) -> some View {
        let draftBinding = Binding<InspectorDraft>(
            get: { viewModel.inspectorDraft ?? InspectorDraft(object: selected) },
            set: { viewModel.updateInspectorDraft($0) }
        )

        return InspectorPanel(title: viewModel.inspectorTitle) {
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
            case .table:
                TableInspector(draft: draftBinding, titleIssues: viewModel.selectedTitleIssues)
            case .seating:
                SeatingInspector(draft: draftBinding, titleIssues: viewModel.selectedTitleIssues)
            case .wall:
                WallInspector(
                    draft: draftBinding,
                    lengthRange: viewModel.sizeRangeM
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
            Button("Delete \(selected.kind.displayName.lowercased())", role: .destructive) {
                viewModel.deleteSelected()
            }
            .buttonStyle(.plain)
            .font(Typography.body)
            .foregroundStyle(Palette.destructive)
        }
    }

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
            Button("Delete \(viewModel.groupSelection?.memberIDs.count ?? 0) \(noun)", role: .destructive) {
                viewModel.requestDeleteGroup()
            }
            .buttonStyle(.plain)
            .font(Typography.body)
            .foregroundStyle(Palette.destructive)
        }
    }

    private var layoutInfoInspector: some View {
        InspectorPanel(title: viewModel.activeLayout?.name ?? "Layout") {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let layout = viewModel.activeLayout {
                    let widthText = DimensionInput.text(for: layout.sizeM.x)
                    let lengthText = DimensionInput.text(for: layout.sizeM.y)
                    infoRow(label: "Dimensions", value: "\(widthText) × \(lengthText) m")
                    infoRow(label: "Area", value: String(format: "%.0f m²", layout.sizeM.x * layout.sizeM.y))

                    Divider().overlay(Palette.surfaceBorder)

                    infoRow(label: "Booths", value: "\(layout.objects.filter { $0.kind == .booth }.count)")
                    infoRow(label: "Doors", value: "\(layout.objects.filter { $0.kind == .door }.count)")
                    infoRow(label: "Total Objects", value: "\(layout.objects.count)")

                    Divider().overlay(Palette.surfaceBorder)

                    validationSection
                } else {
                    Text("No active layout")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        } footer: {
            EmptyView()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(Typography.inspectorLabelDetail)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var validationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Validation")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textSecondary)

            if viewModel.issues.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.accent)
                    Text("No issues detected")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                }
            } else {
                ValidationIssueList(issues: viewModel.issues, onFocus: onFocusIssue)
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
