import SwiftUI

/// Main container view for the 3D venue simulation viewer.
/// Embeds the SceneKit 3D scene with HUD overlays for live metrics and playback controls.
struct SimulationView: View {
    @State private var viewModel: SimulationViewModel
    var onDismiss: (() -> Void)?

    init(viewModel: SimulationViewModel, onDismiss: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.onDismiss = onDismiss
    }

    init(layout: Layout, onDismiss: (() -> Void)? = nil) {
        _viewModel = State(initialValue: SimulationViewModel(layout: layout))
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // 3D SceneKit viewport
            Simulation3DSceneView(
                layout: viewModel.layout,
                visitors: viewModel.visitors,
                densityCells: viewModel.densityCells,
                showHeatmap: viewModel.showHeatmap
            )
            .ignoresSafeArea()

            // Top and bottom HUD overlays
            VStack {
                headerOverlay
                    .padding(.top, Spacing.m)
                    .padding(.horizontal, Spacing.l)

                Spacer()

                bottomControlsOverlay
                    .padding(.bottom, Spacing.l)
                    .padding(.horizontal, Spacing.l)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                if viewModel.isRunning {
                    viewModel.tick(realSeconds: 0.05)
                }
            }
        }
    }

    // MARK: - Top HUD

    private var headerOverlay: some View {
        HStack(spacing: Spacing.m) {
            if let onDismiss {
                backButton(action: onDismiss)
            }

            layoutInfoBadge

            metricsBadge

            Spacer()

            cameraTipsPill
        }
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chevron.left")
                Text("Analysis")
            }
            .font(Typography.body)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Palette.surface.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s)
                    .stroke(Palette.surfaceBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to Analysis")
    }

    private var layoutInfoBadge: some View {
        let layout = viewModel.layout
        let dimensions = "\(Int(layout.sizeM.x))m × \(Int(layout.sizeM.y))m"
        let boothCount = layout.objects.filter { $0.kind == .booth }.count

        return HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name.isEmpty ? "3D Venue" : layout.name)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)

                Text("\(dimensions) · \(boothCount) booths")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            if viewModel.availableLayouts.count > 1 {
                Menu {
                    ForEach(viewModel.availableLayouts) { item in
                        Button(item.name) {
                            viewModel.selectLayout(item)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private var metricsBadge: some View {
        let metrics = viewModel.metrics
        let densityText = String(format: "%.2f /m²", metrics.peakDensity)

        return HStack(spacing: Spacing.l) {
            metricItem(title: "Time", value: viewModel.clockString)
            metricItem(title: "Inside", value: "\(metrics.peopleInside)")
            metricItem(title: "Arrived", value: "\(metrics.arrivals)")
            metricItem(title: "Visits", value: "\(metrics.totalVisits)")
            metricItem(title: "Peak Density", value: densityText)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private func metricItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(Typography.body.monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var cameraTipsPill: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "hand.draw")
                .font(Typography.caption)
            Text("Drag to orbit · Scroll to zoom")
                .font(Typography.caption)
        }
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface.opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    // MARK: - Bottom Playback Controls

    private var bottomControlsOverlay: some View {
        VStack(spacing: Spacing.s) {
            if viewModel.hasRecordedFootage && viewModel.totalFrames > 1 {
                footageScrubberRow
            }

            HStack(spacing: Spacing.m) {
                // Play / Pause button
                Button {
                    viewModel.togglePlay()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        Text(viewModel.isRunning ? "Pause" : "Play")
                    }
                    .frame(minWidth: 80)
                }
                .buttonStyle(.primary)

                // Speed buttons
                HStack(spacing: Spacing.xs) {
                    ForEach([1.0, 5.0, 20.0, 60.0], id: \.self) { speed in
                        speedButton(for: speed)
                    }
                }

                // Fast forward +5 min
                Button("+5 min") {
                    viewModel.fastForward(minutes: 5)
                }
                .buttonStyle(.secondary)

                // Reset / Rerun button
                Button("Reset") {
                    viewModel.reset()
                }
                .buttonStyle(.secondary)

                if viewModel.hasRecordedFootage {
                    Button("Rerun Live") {
                        viewModel.rerunLive()
                    }
                    .buttonStyle(.secondary)
                }

                // Heatmap toggle
                Button {
                    viewModel.showHeatmap.toggle()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: viewModel.showHeatmap ? "square.grid.3x3.fill" : "square.grid.3x3")
                        Text("Heatmap")
                    }
                }
                .buttonStyle(.secondary)

                Spacer()

                // Visitor state legend
                visitorLegend
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .background(Palette.surface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private var footageScrubberRow: some View {
        HStack(spacing: Spacing.m) {
            Label("Saved Footage", systemImage: "film")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)

            Slider(
                value: Binding(
                    get: { Double(viewModel.currentFrameIndex) },
                    set: { viewModel.seekToFrame(Int($0.rounded())) }
                ),
                in: 0...Double(max(1, viewModel.totalFrames - 1)),
                step: 1
            )

            Text("Frame \(viewModel.currentFrameIndex + 1) / \(viewModel.totalFrames)")
                .font(Typography.caption.monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 110, alignment: .trailing)
        }
    }

    private func speedButton(for speed: Double) -> some View {
        let isSelected = viewModel.speedMultiplier == speed
        return Button("\(Int(speed))×") {
            viewModel.speedMultiplier = speed
        }
        .font(Typography.caption)
        .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(isSelected ? Palette.accent.opacity(0.35) : Palette.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(isSelected ? Palette.accent : Palette.surfaceBorder, lineWidth: 1)
        )
        .buttonStyle(.plain)
    }

    private var visitorLegend: some View {
        HStack(spacing: Spacing.m) {
            legendDot(color: .blue, label: "Walking")
            legendDot(color: .orange, label: "Queueing")
            legendDot(color: .purple, label: "Browsing")
            legendDot(color: .green, label: "Leaving")
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

#Preview("Small Market") {
    SimulationView(layout: PreviewLayouts.smallMarket())
}

#Preview("Beyond Market") {
    SimulationView(layout: PreviewLayouts.beyond())
}
