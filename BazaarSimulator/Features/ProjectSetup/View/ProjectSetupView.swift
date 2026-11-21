import SwiftUI
import UniformTypeIdentifiers

struct ProjectSetupView: View {
    @Bindable var viewModel: ProjectSetupViewModel
    @State private var importTarget: ImportFileKind?
    @State private var lastImportTarget: ImportFileKind?
    @State private var dialog: AppDialogContent?
    @State private var previewedFileID: UUID?
    @AppStorage(DevMode.defaultsKey) private var isDevModeOn = false

    /// Wide enough that the side margins stay small; only very wide windows center the content.
    private static let maxContentWidth: CGFloat = 1400

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.bottom, Spacing.xl)

            ScrollView {
                columnsView
            }

            Spacer(minLength: Spacing.m)

            footerView

            if isDevModeOn {
                ImportLogPanel(entries: viewModel.logEntries)
                    .padding(.top, Spacing.m)
            }
        }
        .padding(Spacing.xl)
        // The title bar only reserves room in a window, not in full screen. Ignoring it and padding by a fixed
        // amount keeps the name field at the same height in both.
        .padding(.top, Spacing.m)
        // Capped, so with the sidebar hidden the content stays centered instead of stretching across the window.
        .frame(maxWidth: Self.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background.ignoresSafeArea())
        .underToolbarInWindow()
        .fileImporter(
            isPresented: Binding(
                get: { importTarget != nil },
                set: { if !$0 { importTarget = nil } }
            ),
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            let target = importTarget ?? lastImportTarget
            importTarget = nil
            lastImportTarget = nil
            guard case .success(let urls) = result, let target else { return }
            switch target {
            case .legend:
                viewModel.addLegendFiles(urls: urls)
            case .floorPlan:
                viewModel.addFloorPlanFiles(urls: urls)
            }
        }
        .onChange(of: viewModel.unsupportedFileName) { _, name in
            guard let name else { return }
            dialog = AppDialogContent(
                title: "Unsupported File",
                message: Text("“\(name)” isn’t supported. Please upload a PDF."),
                kind: .notice(symbol: "doc.badge.exclamationmark", buttonTitle: "Ok")
            )
            viewModel.clearUnsupportedFile()
        }
        .appDialog($dialog)
        .layoutPreview(previewedFileID.flatMap(viewModel.previewLayout)) {
            previewedFileID = nil
        }
    }

    // MARK: Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            TextField("Project name", text: $viewModel.projectName)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(width: 250, height: 34)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: Radius.s))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .stroke(Palette.fieldBorder, lineWidth: 1)
                )
                .accessibilityLabel("Project name")

            Text("Import your venue legend and layout.")
                .font(Typography.subtitle)
                .foregroundColor(Palette.textSecondary)
        }
    }

    private var columnsView: some View {
        OneToTwoColumns(spacing: Spacing.xl) {
            legendColumn
            floorPlanColumn
        }
    }

    // MARK: Legends

    private var legendColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SetupCard(
                title: "Legends",
                subtitle: viewModel.legendEntries.isEmpty ? nil : "\(viewModel.legendEntries.count) Elements",
                bottomPadding: legendHasRows ? Self.listBottomPadding : Spacing.m,
                help: { legendHelp },
                trailing: {
                    if !viewModel.legendEntries.isEmpty {
                        Button(action: viewModel.deleteAllLegends) {
                            Text("Clear All")
                                .font(.system(size: 11.5))
                                .foregroundColor(Palette.textPrimary)
                                .padding(.horizontal, Spacing.m)
                                .frame(height: 24)
                                .background(Palette.control, in: RoundedRectangle(cornerRadius: Radius.s))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                },
                content: { legendContent }
            )

            if viewModel.showsLegendRequired {
                Label("Legend required. Please upload a legend to continue.", systemImage: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.destructive)
                    .padding(.leading, 2)
            }
        }
    }

    @ViewBuilder
    private var legendContent: some View {
        if viewModel.pendingLegendRows.isEmpty && viewModel.legendEntries.isEmpty {
            DropZone(
                hint: "PDF · one legend for all the layouts",
                onChoose: { choose(.legend) },
                onDrop: viewModel.addLegendFiles
            )
        } else {
            VStack(spacing: 0) {
                ForEach(viewModel.pendingLegendRows) { row in
                    PlanFileRow(
                        display: row,
                        onDelete: { confirmDeletion(of: row, remove: viewModel.deleteLegendFile) },
                        onRetry: { viewModel.retryLegendFile(id: row.id) }
                    )
                }

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
                        type: entry.type,
                        onTypeChange: { viewModel.setLegendEntryType(id: entry.id, to: $0) },
                        onRemove: { viewModel.removeLegendEntry(id: entry.id) }
                    )
                }

                if !viewModel.legendEntries.isEmpty {
                    addRow(title: "Add Legends") { choose(.legend) }
                }
            }
        }
    }

    /// Space under the last row of a list, so a card with files ends the way the design shows it.
    private static let listBottomPadding: CGFloat = 4

    private var legendHasRows: Bool {
        !viewModel.pendingLegendRows.isEmpty || !viewModel.legendEntries.isEmpty
    }

    private var legendHelp: some View {
        SetupHelpPopover(
            title: "What is a Legend?",
            summary: "A reference that explains the symbols and colors used in your floor plan.",
            itemsTitle: "Example of a good legend"
        ) {
            SetupHelpItem(mark: .dot(.red), text: "Booth A (Foods)")
            SetupHelpItem(mark: .dot(.green), text: "Booth B (Goods)")
        }
    }

    // MARK: Layouts

    private var floorPlanColumn: some View {
        SetupCard(
            title: "Layouts",
            subtitle: viewModel.floorPlanFiles.isEmpty ? nil : "\(viewModel.planRows.count) Plans",
            bottomPadding: viewModel.floorPlanFiles.isEmpty ? Spacing.m : Self.listBottomPadding,
            help: { layoutHelp },
            content: { floorPlanContent }
        )
        .disabled(!viewModel.hasLegend && viewModel.floorPlanFiles.isEmpty)
    }

    @ViewBuilder
    private var floorPlanContent: some View {
        if viewModel.floorPlanFiles.isEmpty {
            DropZone(
                hint: "PDF · one page per layout",
                onChoose: { choose(.floorPlan) },
                onDrop: viewModel.addFloorPlanFiles
            )
            .disabled(!viewModel.isFloorPlanZoneEnabled)
        } else {
            VStack(spacing: 0) {
                ForEach(viewModel.planRows) { row in
                    PlanFileRow(
                        display: row,
                        onEdit: { viewModel.editLayout(fileID: row.id) },
                        onPreview: {
                            if viewModel.previewLayout(fileID: row.id) != nil {
                                previewedFileID = row.id
                            }
                        },
                        onDelete: { confirmDeletion(of: row, remove: viewModel.deleteFloorPlan) },
                        onRetry: { viewModel.retryFloorPlan(id: row.id) }
                    )
                }

                addRow(title: "Add Layout") { choose(.floorPlan) }
                    .disabled(!viewModel.isFloorPlanZoneEnabled)
            }
        }
    }

    private var layoutHelp: some View {
        SetupHelpPopover(
            title: "What is a Layout?",
            summary: "A 2D layout of your venue that shows the space, booths, and facilities.",
            itemsTitle: "A good layout is:"
        ) {
            SetupHelpItem(mark: .check, text: "A clear, readable layout")
            SetupHelpItem(mark: .check, text: "Includes booths and key facilities")
            SetupHelpItem(mark: .check, text: "In PDF format, one page per layout")
        }
    }

    // MARK: Pieces

    private func addRow(title: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(Palette.surfaceBorder)
            Button(action: action) {
                Label(title, systemImage: "plus")
                    .font(.system(size: 11.5))
                    .foregroundColor(Palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Spacing.m)
    }

    private func choose(_ kind: ImportFileKind) {
        lastImportTarget = kind
        importTarget = kind
    }

    /// A file still being read is cancelled at once. Any other file is deleted only after the user confirms.
    private func confirmDeletion(of row: PlanRowDisplay, remove: @escaping (UUID) -> Void) {
        switch row.status {
        case .reading, .waiting:
            remove(row.id)
        case .done, .failed, .cancelled:
            dialog = AppDialogContent(
                title: "Delete this file?",
                message: Text("Are you sure you want to delete ")
                    + Text(row.title).bold()
                    + Text(" from this project?"),
                kind: .confirm(confirmTitle: "Delete", action: { remove(row.id) })
            )
        }
    }

    // MARK: Footer

    private var footerView: some View {
        HStack(spacing: Spacing.m) {
            Spacer()

            if let text = footerText {
                Text(text)
                    .font(Typography.caption)
                    .foregroundColor(viewModel.isStatusError ? Palette.destructive : Palette.textSecondary)
            }

            // Saves the draft and opens the Parameters sheet, once, from the app root.
            Button("Set Parameters") {
                viewModel.continueToReview()
            }
            .buttonStyle(.highlight)
            .disabled(!viewModel.isContinueEnabled)
        }
    }

    /// What is holding Set Parameters back, if anything. Nothing is said once it is ready.
    private var footerText: String? {
        let text = viewModel.statusText
        return text.isEmpty || text == "Ready to continue" ? nil : text
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
