import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProjectSetupView: View {
    @Bindable var viewModel: ProjectSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, Spacing.xxl)

            projectNameRow
                .padding(.bottom, Spacing.xl)

            ScrollView {
                columnsView
            }

            Spacer(minLength: Spacing.m)

            footerView
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.background)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Project")
                .font(Typography.title)
                .foregroundColor(Palette.textPrimary)

            Text("Imported your venue layout and a legend.")
                .font(Typography.subtitle)
                .foregroundColor(Palette.textSecondary)
        }
    }

    private var projectNameRow: some View {
        HStack(spacing: Spacing.m) {
            Text("Project name")
                .font(Typography.fieldLabel)
                .foregroundColor(Palette.textPrimary)

            TextField("Project name", text: $viewModel.projectName)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .foregroundColor(Palette.textPrimary)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .frame(width: 220)
                .background(Palette.field)
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .stroke(Palette.fieldBorder, lineWidth: 1)
                )
        }
    }

    private var columnsView: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            legendColumn
                .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: Spacing.xl)

            floorPlanColumn
                .containerRelativeFrame(.horizontal, count: 3, span: 2, spacing: Spacing.xl)
        }
    }

    private var legendColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("LEGENDS")
                .sectionLabel()

            DropZone(
                hint: "PDF · one legend for all the layouts",
                onChoose: { openFileDialog(allowsMultiple: true, onSelect: viewModel.addLegendFiles) },
                onDrop: viewModel.addLegendFiles
            )

            if !viewModel.pendingLegendRows.isEmpty || !viewModel.legendEntries.isEmpty {
                scannedLegendsCard
            }
        }
    }

    private var scannedLegendsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            let label = viewModel.legendEntries.isEmpty
                ? "LEGEND"
                : "SCANNED LEGENDS · \(viewModel.legendEntries.count) Elements"
            Text(label)
                .sectionLabel()

            VStack(spacing: Spacing.xs) {
                if !viewModel.pendingLegendRows.isEmpty {
                    ForEach(viewModel.pendingLegendRows) { row in
                        PlanFileRow(
                            display: row,
                            onDelete: { viewModel.deleteLegendFile(id: row.id) },
                            onRetry: { viewModel.retryLegendFile(id: row.id) }
                        )
                    }
                } else {
                    ForEach(viewModel.legendEntries) { entry in
                        LegendEntryRow(
                            name: entry.name,
                            color: Color(
                                .sRGB,
                                red: entry.color.red,
                                green: entry.color.green,
                                blue: entry.color.blue,
                                opacity: 1.0
                            ),
                            onRemove: { viewModel.removeLegendEntry(id: entry.id) }
                        )
                    }
                }
            }
            .padding(Spacing.l)
            .card()
        }
    }

    private var floorPlanColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("FLOOR PLANS")
                .sectionLabel()

            DropZone(
                hint: "PDF · one file per layout · up to 6",
                onChoose: { openFileDialog(allowsMultiple: true, onSelect: viewModel.addFloorPlanFiles) },
                onDrop: viewModel.addFloorPlanFiles
            )
            .disabled(!viewModel.isFloorPlanZoneEnabled)

            if !viewModel.floorPlanFiles.isEmpty {
                uploadedPlansCard
            }
        }
    }

    private var uploadedPlansCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("UPLOADED · \(viewModel.floorPlanFiles.count) Plans")
                .sectionLabel()

            VStack(spacing: 0) {
                ForEach(Array(viewModel.floorPlanFiles.enumerated()), id: \.element.id) { index, file in
                    let display = ImportRowFormatter.formatRow(file: file, layoutIndex: index + 1)
                    PlanFileRow(
                        display: display,
                        onEdit: {},
                        onDelete: { viewModel.deleteFloorPlan(id: file.id) },
                        onRetry: { viewModel.retryFloorPlan(id: file.id) }
                    )

                    if index < viewModel.floorPlanFiles.count - 1 {
                        Divider()
                            .background(Palette.surfaceBorder)
                    }
                }
            }
            .padding(.horizontal, Spacing.l)
            .card()
        }
    }

    private var footerView: some View {
        HStack(spacing: Spacing.m) {
            Spacer()

            Text(viewModel.statusText)
                .font(Typography.caption)
                .foregroundColor(Palette.textSecondary)

            Button("Cancel") {
                viewModel.cancel()
            }
            .buttonStyle(.secondary)
            .disabled(!viewModel.isCancelEnabled)

            Button("Continue") {
                viewModel.continueToReview()
            }
            .buttonStyle(.primary)
            .disabled(!viewModel.isContinueEnabled)
        }
    }

    private func openFileDialog(allowsMultiple: Bool, onSelect: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK {
            onSelect(panel.urls)
        }
    }
}

#Preview("Screen 2: Initial Setup") {
    let session = ProjectSession()
    let project = session.createProject(named: "Bazaar 1")
    let queue = ScriptedImportQueue()
    let viewModel = ProjectSetupViewModel(
        projectID: project.id,
        session: session,
        importQueue: queue,
        onContinue: { _ in }
    )

    return ProjectSetupView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Screen 3: Legend Read") {
    let session = ProjectSession()
    let project = session.createProject(named: "Bazaar 1")
    let queue = ScriptedImportQueue(isSynchronous: true)
    let viewModel = ProjectSetupViewModel(
        projectID: project.id,
        session: session,
        importQueue: queue,
        onContinue: { _ in }
    )
    viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])

    return ProjectSetupView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Screen 4: Plans Uploaded") {
    let session = ProjectSession()
    let project = session.createProject(named: "Bazaar 1")
    let queue = ScriptedImportQueue(isSynchronous: false)
    let viewModel = ProjectSetupViewModel(
        projectID: project.id,
        session: session,
        importQueue: queue,
        onContinue: { _ in }
    )

    viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
    queue.insert(ImportFile(
        projectID: project.id,
        url: URL(fileURLWithPath: "/tmp/layout1.pdf"),
        kind: .floorPlan,
        state: .done(booths: 66, doors: 3),
        fileSize: 2_516_582
    ))
    queue.insert(ImportFile(
        projectID: project.id,
        url: URL(fileURLWithPath: "/tmp/layout2.pdf"),
        kind: .floorPlan,
        state: .done(booths: 66, doors: 3),
        fileSize: 2_726_298
    ))
    queue.insert(ImportFile(
        projectID: project.id,
        url: URL(fileURLWithPath: "/tmp/layout3.pdf"),
        kind: .floorPlan,
        state: .reading(progress: 0.5),
        fileSize: 1_887_436
    ))

    return ProjectSetupView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
