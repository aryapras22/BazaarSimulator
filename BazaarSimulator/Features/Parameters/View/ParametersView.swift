import SwiftUI

struct ParametersView: View {
    @Bindable var viewModel: ParametersViewModel
    var width: CGFloat = 860
    var showsBackground: Bool = true
    @State private var commitScope = FormCommitScope()

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, Spacing.l)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    totalVisitorsRow
                    divider
                    eventDurationRow
                    divider
                    bazaarAndVisitorRows
                }
            }

            footerView
                .padding(.top, Spacing.l)
        }
        .environment(\.formCommitScope, commitScope)
        .padding(Spacing.xl)
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)

        Group {
            if showsBackground {
                content.glassCardSurface(in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            } else {
                content
            }
        }
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Divider().background(Palette.surfaceBorder)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Parameter")
                .font(Typography.title)
                .foregroundColor(Palette.textPrimary)
            Text("Applies to every layout in this project")
                .font(Typography.subtitle)
                .foregroundColor(Palette.textSecondary)
        }
    }

    private var totalVisitorsRow: some View {
        ParameterRow(title: "Total Visitors", subtitle: "Estimated number of visitors per day.") {
            CommitField(value: viewModel.totalVisitorsText, suffix: "people") {
                viewModel.commitTotalVisitors($0)
            }
            .frame(width: 234)
        }
    }

    private var eventDurationRow: some View {
        ParameterRow(title: "Event Duration", subtitle: "Set number of hours the event per day.") {
            HStack(spacing: Spacing.s) {
                CommitField(value: viewModel.startText, suffix: "start") { viewModel.commitStart($0) }
                CommitField(value: viewModel.endText, suffix: "end") { viewModel.commitEnd($0) }
            }
            .frame(width: 250)
        }
    }

    private var bazaarAndVisitorRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParameterRow(title: "Bazaar Type", subtitle: "Set bazaar type.") {
                DropdownField(
                    options: viewModel.catalog.bazaarTypes.map(\.id),
                    selection: $viewModel.bazaarTypeID,
                    title: { viewModel.bazaarTypeTitle(for: $0) }
                )
                .frame(width: 234)
            }

            ParameterRow(title: "Visitor Type", subtitle: "Set the proportion of each type.") {
                VisitorSlider(
                    items: VisitorSliderItem.items(for: viewModel.catalog.visitorTypes),
                    mix: viewModel.mix,
                    onChange: { viewModel.setPercent($1, for: $0) },
                    onToggleLock: { viewModel.toggleLock(for: $0) }
                )
            }
        }
    }

    private var footerView: some View {
        HStack(spacing: Spacing.m) {
            Spacer()
            Button("Cancel") { viewModel.cancel() }
                .buttonStyle(.secondary)
                .keyboardShortcut(.cancelAction)
            Button("Apply") {
                commitScope.commitAll()
                viewModel.apply()
            }
            .buttonStyle(.primary(fill: Palette.actionOrange))
        }
    }
}

#Preview("Parameters") {
    let session = ProjectSession()
    let project = session.createProject(named: "Bazaar 1")
    let viewModel = ParametersViewModel(
        projectID: project.id,
        session: session,
        catalog: PresetCatalog.bundled(),
        onClose: {}
    )

    return ParametersView(viewModel: viewModel)
        .padding(Spacing.xl)
        .background(Palette.background)
        .preferredColorScheme(.dark)
}
