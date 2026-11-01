import SwiftUI

struct ProjectLibraryView: View {
    @Bindable var viewModel: ProjectLibraryViewModel

    var body: some View {
        VStack(spacing: Spacing.m) {
            headerView

            ScrollView {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(viewModel.filteredProjects) { project in
                        Button {
                            viewModel.selectProject(project)
                        } label: {
                            ProjectRow(
                                name: project.name,
                                isSelected: viewModel.selectedProjectId == project.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            SidebarSearchField(text: $viewModel.searchText)
        }
        .padding(Spacing.m)
        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.sidebarBase.opacity(0.85))
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
    let router = AppRouter()
    let viewModel = ProjectLibraryViewModel(session: session, router: router)
    viewModel.projects = [
        ProjectItem(name: "Bazaar 1"),
        ProjectItem(name: "Bazaar 2")
    ]
    viewModel.selectedProjectId = viewModel.projects[0].id

    return ProjectLibraryView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
