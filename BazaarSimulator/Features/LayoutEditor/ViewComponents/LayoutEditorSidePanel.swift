import SwiftUI

struct LayoutEditorSidePanel: View {
    @Bindable var viewModel: LayoutEditorViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            header

            if viewModel.inspectorPanelTab == .library {
                LibraryPanel(
                    rows: viewModel.libraryRows,
                    searchText: $viewModel.librarySearch,
                    onSelect: { viewModel.startPlacing($0) }
                )
            } else {
                BoothGroupsList(
                    nameRows: viewModel.nameGroupRows,
                    sizeRows: viewModel.sizeGroupRows,
                    onHover: { viewModel.hoveredGroup = $0 },
                    onSelect: { viewModel.selectGroup($0) }
                )
            }
        }
        .padding(Spacing.m)
        .frame(width: 280)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Palette.surfaceBorder)
                .frame(width: 1)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            SegmentedTabs(
                selection: $viewModel.inspectorPanelTab,
                tabs: InspectorPanelTab.allCases,
                title: \.title
            )

            Spacer(minLength: 0)

            Button {
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Collapse panel")
            .accessibilityLabel("Collapse panel")
        }
    }
}

#Preview {
    let session = ProjectSession()
    let project = session.createProject(named: "Preview Market")
    let layout = PreviewLayouts.smallMarket()
    session.setDraft(
        ProjectDraft(name: "Preview Market", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
        for: project.id
    )
    let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
    return LayoutEditorSidePanel(viewModel: viewModel, onClose: {})
        .frame(height: 500)
        .preferredColorScheme(.dark)
}
