import SwiftUI

struct ProjectLibraryView: View {
    @Bindable var viewModel: ProjectLibraryViewModel

    var body: some View {
        VStack(spacing: Spacing.m) {
            headerView

            ScrollView {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(viewModel.filteredProjects) { project in
                        projectFolder(project)
                    }
                }
            }

            Spacer(minLength: 0)

            if !viewModel.projects.isEmpty {
                SidebarSearchField(text: $viewModel.searchText)
            }
        }
        .padding(Spacing.m)
        .frame(minWidth: 240, maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func projectFolder(_ project: ProjectSummary) -> some View {
        HStack(spacing: 0) {
            Button {
                viewModel.selectProject(project)
            } label: {
                ProjectRow(
                    name: project.name,
                    isSelected: viewModel.isFolderSelected(project),
                    isExpanded: viewModel.isExpanded(project)
                )
            }
            .buttonStyle(.plain)
        }
        .overlay {
            SidebarContextMenu(items: [
                SidebarMenuItem(title: "Delete", symbol: "trash", isDestructive: true) {
                    viewModel.requestDeletion(of: project)
                }
            ])
        }
        .overlay(alignment: .leading) {
            // The chevron toggles the folder without opening the project.
            Color.clear
                .frame(width: 36)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleExpanded(project) }
                }
        }

        if viewModel.isExpanded(project) {
            let analyses = viewModel.savedAnalyses(in: project)
            ForEach(analyses) { analysis in
                analysisRow(analysis, in: project)
            }
            if viewModel.isRunning(project) {
                runningRow(in: project)
            }
        }
    }

    private func analysisRow(_ analysis: SavedAnalysis, in project: ProjectSummary) -> some View {
        SavedAnalysisRow(
            name: analysis.name,
            detail: analysis.createdAt.formatted(date: .omitted, time: .shortened),
            isSelected: viewModel.isAnalysisSelected(analysis, in: project),
            isRenaming: viewModel.renamingAnalysisID == analysis.id,
            onCommitRename: { viewModel.renameAnalysis(analysis, in: project, to: $0) }
        )
        .padding(.leading, Spacing.l)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.surfaceBorder)
                .frame(width: 1)
                .padding(.leading, Spacing.m + 5)
        }
        .onTapGesture { viewModel.selectAnalysis(analysis, in: project) }
        .overlay {
            SidebarContextMenu(items: [
                SidebarMenuItem(title: "Rename", symbol: "pencil") {
                    viewModel.renamingAnalysisID = analysis.id
                },
                SidebarMenuItem(title: "Delete", symbol: "trash", isDestructive: true) {
                    viewModel.requestDeletion(of: analysis, in: project)
                }
            ])
        }
    }

    private func runningRow(in project: ProjectSummary) -> some View {
        SavedAnalysisRow(
            name: "Running...",
            detail: "",
            isSelected: viewModel.isRunningSelected(project),
            isRenaming: false,
            isLoading: true,
            onCommitRename: { _ in }
        )
        .padding(.leading, Spacing.l)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.surfaceBorder)
                .frame(width: 1)
                .padding(.leading, Spacing.m + 5)
        }
        .onTapGesture { viewModel.openRunning(project) }
    }

    private var headerView: some View {
        HStack {
            Text("Projects")
                .font(Typography.fieldLabel)
                .foregroundColor(Palette.textPrimary)

            Spacer()

            Button {
                viewModel.createProject()
            } label: {
                Image(systemName: "plus")
                    .font(Typography.body)
                    .foregroundColor(Palette.textPrimary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    let session = ProjectSession()
    let first = session.createProject(named: "Bazaar 1")
    session.createProject(named: "Bazaar 2")
    session.selectProject(id: first.id)
    let viewModel = ProjectLibraryViewModel(session: session, onOpenProject: { _ in })

    return ProjectLibraryView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
