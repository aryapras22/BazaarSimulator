import SwiftUI

struct ParametersView: View {
    @Bindable var viewModel: ParametersViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, Spacing.l)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    totalVisitorsRow
                    divider
                    eventDurationRow
                    divider
                    peakHoursRow
                    divider
                    bazaarAndVisitorRows
                    divider
                    groupSizeRow
                }
            }

            footerView
                .padding(.top, Spacing.l)
        }
        .padding(Spacing.xl)
        .frame(minWidth: 860, minHeight: 640)
        .background(Palette.background)
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

    private var peakHoursRow: some View {
        ParameterRow(title: "Peak Hours Period", subtitle: "Add one or more peak hours periods.") {
            HStack(alignment: .top, spacing: Spacing.m) {
                Toggle("Peak hours", isOn: $viewModel.isPeakEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)

                FlowLayout(spacing: Spacing.s) {
                    ForEach(viewModel.peakSlots, id: \.self) { slot in
                        PeakChip(
                            title: slot.label,
                            isSelected: viewModel.isPeakSelected(slot),
                            isEnabled: viewModel.isPeakEnabled,
                            onTap: { viewModel.togglePeak(slot) }
                        )
                    }
                    Button(action: viewModel.addPeakSlot) {
                        Image(systemName: "plus")
                            .foregroundColor(viewModel.canAddPeakSlot ? Palette.textPrimary : Palette.textDisabled)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canAddPeakSlot)
                    .accessibilityLabel("Add peak hours period")
                }
            }
        }
    }

    private var bazaarAndVisitorRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ParameterRow(title: "Bazaar Type", subtitle: "Set bazaar type.") {
                DropdownField(
                    options: viewModel.catalog.bazaarTypes.map(\.id),
                    selection: $viewModel.bazaarTypeID,
                    title: { viewModel.catalog.bazaarType(id: $0)?.name ?? $0 }
                )
                .frame(width: 234)
            }

            ParameterRow(title: "Visitor Type", subtitle: "Set the propostion of each type.") {
                VisitorSlider(
                    items: VisitorSliderItem.items(for: viewModel.catalog.visitorTypes),
                    mix: viewModel.mix,
                    onChange: { viewModel.setPercent($1, for: $0) },
                    onToggleLock: { viewModel.toggleLock(for: $0) }
                )
            }
        }
    }

    private var groupSizeRow: some View {
        ParameterRow(title: "Group Size", subtitle: "Set max amount in each group.") {
            DropdownField(
                options: ParametersViewModel.groupSizeOptions,
                selection: $viewModel.groupSize,
                title: { String($0) }
            )
            .frame(width: 96)
        }
    }

    private var footerView: some View {
        HStack(spacing: Spacing.m) {
            Spacer()
            Button("Cancel") { viewModel.cancel() }
                .buttonStyle(.secondary)
            Button("Apply") { viewModel.apply() }
                .buttonStyle(.primary)
        }
    }
}

/// Places children left to right and wraps to a new row when the width runs out.
private struct FlowLayout: SwiftUI.Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()) -> CGSize {
        let rows = arrange(in: proposal.width ?? 600, subviews: subviews)
        return CGSize(width: rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()) {
        let rows = arrange(in: bounds.width, subviews: subviews)
        for (index, frame) in rows.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(in width: CGFloat, subviews: LayoutSubviews)
        -> (frames: [CGRect], width: CGFloat, height: CGFloat) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (frames, maxX, y + rowHeight)
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
        .preferredColorScheme(.dark)
}
