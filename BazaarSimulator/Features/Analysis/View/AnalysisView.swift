import SwiftUI

/// Main Analysis view showing the simulation heatmap results, summary metrics,
/// hotspot findings, and buttons to edit parameters, edit layouts, or watch the 3D simulation footage.
struct AnalysisView: View {
    let projectID: UUID
    let session: any ProjectSessionProtocol
    var onOpenEditor: () -> Void
    var onOpenSimulation: () -> Void
    var onBackToSetup: (() -> Void)?

    @State private var showParameterModal = false
    @State private var showHeatmapOverlay = true

    private var projectName: String {
        session.projects.first { $0.id == projectID }?.name ?? "Project"
    }

    private var layouts: [Layout] {
        session.draft(for: projectID)?.layouts ?? []
    }

    private var activeLayout: Layout {
        if let activeID = session.activeLayoutID(for: projectID),
           let found = session.layout(id: activeID, in: projectID) {
            return found
        }
        return layouts.first ?? PreviewLayouts.beyond()
    }

    private var currentResult: SimulationResult? {
        session.simulationResult(for: activeLayout.id, in: projectID)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()
                .overlay(Palette.surfaceBorder)

            if let result = currentResult {
                resultsContent(for: result)
            } else {
                emptyResultsPrompt
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .onAppear {
            if currentResult == nil && !layouts.isEmpty {
                session.runSimulations(for: projectID)
            }
        }
        .sheet(isPresented: $showParameterModal) {
            EditParameterView(
                projectID: projectID,
                session: session
            )
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: Spacing.m) {
            if let onBackToSetup {
                Button(action: onBackToSetup) {
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

                Text("\(layouts.count) \(layouts.count == 1 ? "layout" : "layouts") · Crowd Density & Flow Analysis")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            if layouts.count > 1 {
                layoutPickerMenu
            }

            Spacer()

            HStack(spacing: Spacing.s) {
                Button {
                    showParameterModal = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "slider.horizontal.2.square")
                        Text("Parameters")
                    }
                }
                .buttonStyle(.secondary)

                Button(action: onOpenEditor) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "pencil.and.ruler")
                        Text("Edit Layouts")
                    }
                }
                .buttonStyle(.secondary)
                .accessibilityLabel("Open Layout Editor")

                Button(action: onOpenSimulation) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "play.rectangle.fill")
                        Text("Watch 3D Footage")
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

    private var layoutPickerMenu: some View {
        Menu {
            ForEach(layouts) { item in
                Button(item.name) {
                    session.setActiveLayoutID(item.id, for: projectID)
                }
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(activeLayout.name)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: Radius.s))
            .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(Palette.surfaceBorder, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Results Content

    private func resultsContent(for result: SimulationResult) -> some View {
        HStack(spacing: 0) {
            // Left: 2D Heatmap Floor Plan
            VStack(spacing: 0) {
                heatmapHeader(for: result)
                LayoutHeatmapCanvas(
                    layout: activeLayout,
                    densityCells: result.densityCells,
                    showHeatmap: showHeatmapOverlay
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                heatmapLegendBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(Palette.surfaceBorder)

            // Right: Metrics, Hotspots, and Footage CTA
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    metricsCard(for: result)
                    hotspotsCard(for: result)
                    adviceCard(for: result)
                    footageCalloutCard(for: result)
                }
                .padding(Spacing.l)
            }
            .frame(width: 360)
            .background(Palette.surface.opacity(0.5))
        }
    }

    private func heatmapHeader(for result: SimulationResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(activeLayout.name) — Crowd Heatmap")
                    .font(Typography.fieldLabel)
                    .foregroundStyle(Palette.textPrimary)
                let dims = "\(Int(activeLayout.sizeM.x))m × \(Int(activeLayout.sizeM.y))m"
                let booths = activeLayout.objects.filter { $0.kind == .booth }.count
                Text("\(dims) · \(booths) booths · \(result.frames.count) footage frames recorded")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Toggle("Show Heatmap", isOn: $showHeatmapOverlay)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface.opacity(0.6))
    }

    private var heatmapLegendBar: some View {
        HStack(spacing: Spacing.l) {
            legendBadge(color: .green, text: "Low (< 0.30 /m²)")
            legendBadge(color: .orange, text: "Moderate (0.30 – 0.72 /m²)")
            legendBadge(color: .red, text: "High Crowding (≥ 0.72 /m²)")
            Spacer()
            Text("Circles mark peak bottleneck hotspots")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface)
    }

    private func legendBadge(color: Color, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.75))
                .frame(width: 12, height: 12)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: - Right Sidebar Cards

    private func metricsCard(for result: SimulationResult) -> some View {
        let metrics = result.metrics
        let grade = SimulationAnalysis.grade(for: metrics.peakDensity)
        let stayMin = Int(metrics.averageStaySeconds) / 60
        let staySec = Int(metrics.averageStaySeconds) % 60

        return VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("SIMULATION SUMMARY")
                    .sectionLabel()
                Spacer()
                Text("Grade \(grade)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        metrics.peakDensity >= 0.72 ? Color.red.opacity(0.4) : Color.green.opacity(0.35),
                        in: Capsule()
                    )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s) {
                metricBox(title: "Peak Density", value: String(format: "%.2f /m²", metrics.peakDensity))
                metricBox(title: "Visitors Arrived", value: "\(metrics.arrivals)")
                metricBox(title: "Booth Visits", value: "\(metrics.totalVisits)")
                metricBox(title: "Queue Skips", value: "\(metrics.queueBalks)")
                metricBox(title: "Avg. Stay", value: String(format: "%02dm %02ds", stayMin, staySec))
                metricBox(title: "Mean Density", value: String(format: "%.2f /m²", metrics.meanDensity))
            }
        }
        .padding(Spacing.m)
        .card()
    }

    private func metricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Typography.body.monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s)
        .background(Palette.background.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.s))
    }

    private func hotspotsCard(for result: SimulationResult) -> some View {
        let findings = SimulationAnalysis.bottlenecks(from: result.densityCells)

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("HOTSPOT LOCATIONS")
                .sectionLabel()

            if findings.isEmpty {
                Text("No high-density bottlenecks detected in this run.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(findings) { finding in
                    HStack {
                        Text("Grade \(finding.grade)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(finding.density >= 0.72 ? Color.red : Color.orange)
                            .frame(width: 62, alignment: .leading)
                        Text(finding.label)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(String(format: "%.2f /m²", finding.density))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(Spacing.m)
        .card()
    }

    private func adviceCard(for result: SimulationResult) -> some View {
        let findings = SimulationAnalysis.bottlenecks(from: result.densityCells)
        let advice = SimulationAnalysis.organizerAdvice(metrics: result.metrics, findings: findings)

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("RECOMMENDATION")
                .sectionLabel()
            Text(advice)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.m)
        .card()
    }

    private func footageCalloutCard(for result: SimulationResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("3D SIMULATION FOOTAGE")
                .sectionLabel()
            Text("Saved \(result.frames.count) snapshots of visitor movement. Watch the recorded 3D footage or scrub the timeline to inspect crowd flow.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)

            Button(action: onOpenSimulation) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Watch 3D Simulation Footage")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
        }
        .padding(Spacing.m)
        .card()
    }

    private var emptyResultsPrompt: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundStyle(Palette.accentIcon)
            Text("Configure Parameters to Run Simulation")
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
            Button("Open Parameters") {
                showParameterModal = true
            }
            .buttonStyle(.primary)
            Spacer()
        }
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
