import SwiftUI

struct ProjectLibraryView: View {
    @Bindable var viewModel: ProjectLibraryViewModel

    /// What a row of the projects list takes, with the gap under it, and the most the list grows to before it scrolls.
    private static let projectRowHeight: CGFloat = 40
    private static let projectsListLimit: CGFloat = 280

    var body: some View {
        VStack(spacing: Spacing.m) {
            headerView

            projectsList

            runsSection

            Spacer(minLength: 0)

            if !viewModel.projects.isEmpty {
                SidebarSearchField(text: $viewModel.searchText)
            }
        }
        .padding(Spacing.m)
        .frame(minWidth: 240, maxWidth: .infinity, maxHeight: .infinity)
        .sidebarBackground()
    }

    // MARK: Projects

    /// The projects on top, one row each. Clicking one opens it, and its runs show under the list.
    private var projectsList: some View {
        let count = viewModel.filteredProjects.count
        return ScrollView {
            LazyVStack(spacing: Spacing.xs) {
                ForEach(viewModel.filteredProjects) { project in
                    projectRow(project)
                }
            }
        }
        .frame(maxHeight: min(CGFloat(count) * Self.projectRowHeight, Self.projectsListLimit))
        .scrollBounceBehavior(.basedOnSize)
    }

    private func projectRow(_ project: ProjectSummary) -> some View {
        Button {
            viewModel.selectProject(project)
        } label: {
            ProjectRow(
                name: project.name,
                isSelected: viewModel.isProjectSelected(project),
                isExpanded: viewModel.isProjectSelected(project),
                showsChevron: false
            )
        }
        .buttonStyle(.plain)
        .overlay {
            SidebarContextMenu(items: [
                SidebarMenuItem(title: "Delete", symbol: "trash", isDestructive: true) {
                    viewModel.requestDeletion(of: project)
                }
            ])
        }
    }

    // MARK: Runs

    /// The selected project's runs, under the projects, like the pages under a tab bar.
    @ViewBuilder
    private var runsSection: some View {
        if let project = viewModel.selectedProject {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Rectangle()
                    .fill(Palette.surfaceBorder)
                    .frame(height: 1)

                HStack(spacing: Spacing.xs) {
                    Text("Runs")
                        .font(Typography.fieldLabel)
                        .foregroundColor(Palette.textPrimary)
                    Text(project.name)
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.xs)

                let analyses = viewModel.savedAnalyses(in: project)
                if analyses.isEmpty, !viewModel.isRunning(project) {
                    Text("No runs yet")
                        .font(Typography.caption)
                        .foregroundColor(Palette.textTertiary)
                        .padding(.horizontal, Spacing.xs)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.xs) {
                            ForEach(analyses) { analysis in
                                analysisRow(analysis, in: project)
                            }
                            if viewModel.isRunning(project) {
                                runningRow(in: project)
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
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
