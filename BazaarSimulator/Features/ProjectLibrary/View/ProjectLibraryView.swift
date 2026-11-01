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
                                isSelected: viewModel.selectedProjectID == project.id
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
        .sidebarBackground()
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
