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

            Spacer()

            metricsBadge
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
            .background(Palette.surface.opacity(0.88), in: Capsule())
            .overlay(Capsule().stroke(Palette.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to Analysis")
    }

    private var layoutInfoBadge: some View {
        let layout = viewModel.layout

        return HStack(spacing: Spacing.s) {
            Text(layout.name.isEmpty ? "3D Venue" : layout.name)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)

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
        .background(Palette.surface.opacity(0.88), in: Capsule())
        .overlay(Capsule().stroke(Palette.surfaceBorder, lineWidth: 1))
    }

    private var metricsBadge: some View {
        let metrics = viewModel.metrics
        let densityText = String(format: "%.2f /m²", metrics.peakDensity)
        let timeLabel = viewModel.hasRecordedFootage
            ? "\(viewModel.timeOfDayString) (\(viewModel.clockString))"
            : viewModel.clockString

        return HStack(spacing: Spacing.l) {
            metricItem(title: "Time", value: timeLabel)
            metricItem(title: "Inside", value: "\(metrics.peopleInside)")
            metricItem(title: "Arrived", value: "\(metrics.arrivals)")
            metricItem(title: "Peak Density", value: densityText)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: Radius.m))
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

    // MARK: - Bottom Playback Controls

    private var bottomControlsOverlay: some View {
        VStack(spacing: Spacing.s) {
            if viewModel.hasRecordedFootage && viewModel.totalFrames > 1 {
                footageScrubberRow
            }

            HStack(spacing: Spacing.m) {
                Button {
                    viewModel.togglePlay()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        Text(viewModel.isRunning ? "Pause" : "Play")
                    }
                    .frame(minWidth: 76)
                }
                .buttonStyle(.primary)

                HStack(spacing: Spacing.xs) {
                    ForEach([1.0, 5.0, 20.0, 60.0], id: \.self) { speed in
                        speedButton(for: speed)
                    }
                }

                Button {
                    viewModel.showHeatmap.toggle()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: viewModel.showHeatmap ? "flame.fill" : "flame")
                        Text("Heatmap")
                    }
                }
                .buttonStyle(.secondary)

                Spacer()

                visitorLegend
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: 740)
        .background(Palette.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private var footageScrubberRow: some View {
        HStack(spacing: Spacing.m) {
            Text(viewModel.clockString)
                .font(Typography.caption.monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 64, alignment: .leading)

            Slider(
                value: Binding(
                    get: { Double(viewModel.currentFrameIndex) },
                    set: { viewModel.seekToFrame(Int($0.rounded())) }
                ),
                in: 0...Double(max(1, viewModel.totalFrames - 1)),
                step: 1
            )

            Text(viewModel.totalDurationString)
                .font(Typography.caption.monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 64, alignment: .trailing)
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
