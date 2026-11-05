import SwiftUI

/// Template view for Analysis, serving as the project default view.
/// Contains placeholders for future analytical metrics, plus direct
/// navigation to the Layout Editor and the 3D Simulation.
struct AnalysisView: View {
    let projectID: UUID
    let session: any ProjectSessionProtocol
    var onOpenEditor: () -> Void
    var onOpenSimulation: () -> Void
    var onBackToSetup: (() -> Void)?

    private var projectName: String {
        session.projects.first { $0.id == projectID }?.name ?? "Project"
    }

    private var draft: ProjectDraft? {
        session.draft(for: projectID)
    }

    private var layoutCount: Int {
        draft?.layouts.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()
                .overlay(Palette.surfaceBorder)

            Spacer()

            mainContent

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Spacing.m) {
            if let onBackToSetup {
                Button {
                    onBackToSetup()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("Setup")
                    }
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Project Setup")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(projectName)
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)

                Text("\(layoutCount) \(layoutCount == 1 ? "layout" : "layouts") available")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer()

            // Quick action buttons in header
            HStack(spacing: Spacing.s) {
                Button {
                    onOpenEditor()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit Layouts")
                    }
                }
                .buttonStyle(.secondary)
                .accessibilityLabel("Open Layout Editor")

                Button {
                    onOpenSimulation()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "cube")
                        Text("3D Simulation")
                    }
                }
                .buttonStyle(.primary)
                .accessibilityLabel("Open 3D Simulation")
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.m)
        .background(Palette.surface)
    }

    // MARK: - Main Placeholder Content

    private var mainContent: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundStyle(Palette.accentIcon)

            VStack(spacing: Spacing.xs) {
                Text("Analysis shown here")
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)

                Text("Layout comparisons, crowd flow rates, and density risk metrics will be available here.")
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            HStack(spacing: Spacing.m) {
                Button {
                    onOpenEditor()
                } label: {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Go to Layout Editor")
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.secondary)

                Button {
                    onOpenSimulation()
                } label: {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "cube")
                        Text("Go to Simulation")
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.primary)
            }
            .padding(.top, Spacing.s)
        }
        .padding(Spacing.xxl)
        .background(Palette.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }
}

#Preview {
    let session = ProjectSession()
    let summary = session.createProject(named: "Annyeong Market")
    return AnalysisView(
        projectID: summary.id,
        session: session,
        onOpenEditor: {},
        onOpenSimulation: {}
    )
    .preferredColorScheme(.dark)
}
