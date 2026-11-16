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
                                    && viewModel.selectedResultTabID == nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if viewModel.selectedProjectID != nil, !viewModel.resultTabs.isEmpty {
                Divider()
                    .background(Palette.surfaceBorder)

                resultsSection
            }

            Spacer(minLength: 0)

            SidebarSearchField(text: $viewModel.searchText)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Results")
                .font(Typography.fieldLabel)
                .foregroundColor(Palette.textPrimary)
                .padding(.bottom, 2)

            ScrollView {
                LazyVStack(spacing: Spacing.xs) {
                    ForEach(viewModel.resultTabs) { tab in
                        Button {
                            viewModel.selectResultTab(tab)
                        } label: {
                            ResultTabRow(
                                title: tab.title,
                                subtitle: tab.subtitle,
                                isSelected: viewModel.selectedResultTabID == tab.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 190)
        }
    }
}

private struct ResultTabRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "chart.bar.xaxis")
                .foregroundColor(isSelected ? Palette.accentIcon : Palette.textSecondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Typography.body)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundColor(Palette.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(isSelected ? Palette.selection : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(isSelected ? Palette.selectionBorder : Color.clear, lineWidth: 1)
        )
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
