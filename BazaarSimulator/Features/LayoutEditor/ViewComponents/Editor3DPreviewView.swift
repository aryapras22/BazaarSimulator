import SwiftUI

/// Compact 2D / 3D segmented control for switching the layout editor viewport into read-only 3D preview.
struct EditorViewportModeToggle: View {
    @Binding var is3DPreview: Bool

    var body: some View {
        SegmentedTabs(
            selection: $is3DPreview,
            tabs: [false, true],
            title: { $0 ? "3D" : "2D" }
        )
        .accessibilityLabel("Viewport mode")
    }
}

/// Hosts the layout editor viewport, swapping between the 2D canvas and the read-only 3D preview with a 2D / 3D toggle.
struct EditorViewportContainer<TwoDContent: View>: View {
    @Binding var is3DPreview: Bool
    let layout: Layout?
    var background: CanvasBackground = .grey
    @ViewBuilder let twoDContent: () -> TwoDContent

    @State private var venueBuilder = Editor3DVenueBuilder()
    @State private var previewVenue: SimulationVenue?

    var body: some View {
        Group {
            if is3DPreview {
                Editor3DPreviewView(venue: previewVenue, backgroundColor: background.fill)
            } else {
                twoDContent()
            }
        }
        .overlay(alignment: .topLeading) {
            EditorViewportModeToggle(is3DPreview: toggleBinding)
                .padding(.leading, is3DPreview ? Spacing.l : CanvasRulers.leftWidth + Spacing.m)
                .padding(.top, is3DPreview ? Spacing.l : CanvasRulers.topHeight + Spacing.m)
        }
        .clipped()
        .onAppear {
            guard is3DPreview else { return }
            previewVenue = layout.map { venueBuilder.venue(for: $0) }
        }
        .onChange(of: layout) { _, newLayout in
            guard is3DPreview else { return }
            previewVenue = newLayout.map { venueBuilder.venue(for: $0) }
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { is3DPreview },
            set: { enabled in
                if enabled {
                    previewVenue = layout.map { venueBuilder.venue(for: $0) }
                }
                is3DPreview = enabled
            }
        )
    }
}

/// Read-only header bar shown while the layout editor is in 3D preview, keeping Back active while disabling Undo/Redo.
struct Editor3DHeaderBar: View {
    let layoutTitle: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            headerButton(
                "chevron.left",
                label: "Back to Analysis",
                help: "Back to Analysis",
                enabled: true,
                isRound: true,
                action: onBack
            )

            Text(layoutTitle)
                .font(Typography.panelTitle)
                .foregroundStyle(Palette.textPrimary)

            Spacer(minLength: Spacing.l)

            HStack(spacing: Spacing.s) {
                headerButton("arrow.uturn.backward", label: "Undo", help: "Undo (⌘Z)", enabled: false, action: {})
                headerButton("arrow.uturn.forward", label: "Redo", help: "Redo (⇧⌘Z / ⌘Y)", enabled: false, action: {})
            }
        }
        .frame(height: ToolbarMetrics.controlSize)
    }

    private func headerButton(
        _ symbol: String,
        label: String,
        help: String,
        enabled: Bool,
        isRound: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        // Back is a circle. Undo and Redo use the shape of every other button.
        let shape = AnyShape(isRound ? AnyShape(Circle()) : AnyShape(RoundedRectangle.button))
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: ToolbarMetrics.iconFontSize, weight: .medium))
                .foregroundStyle(Palette.textPrimary.opacity(enabled ? 1 : 0.35))
                .frame(width: ToolbarMetrics.controlSize, height: ToolbarMetrics.controlSize)
                .background(shape.fill(Palette.surface))
                .overlay(shape.stroke(Palette.surfaceBorder, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(label)
    }
}

/// Read-only 3D preview of the active layout inside the layout editor. Supports orbit, pan, and zoom only.
struct Editor3DPreviewView: View {
    let venue: SimulationVenue?
    var backgroundColor: Color = Palette.canvasBackgroundGrey

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let venue {
                Metal3DSceneView(venue: venue, frame: SimulationSceneFrame(), backgroundColor: backgroundColor)
                    .accessibilityLabel("Read-only 3D layout preview")

                readOnlyBadge
                    .padding(.leading, Spacing.l)
                    .padding(.bottom, Spacing.l)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }

    private var readOnlyBadge: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: "eye")
                .font(Typography.caption)
                .foregroundStyle(Palette.accentIcon)
            Text("Read-only 3D · Drag to orbit, Shift-drag to pan, scroll to zoom")
                .font(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .fill(Palette.surface.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(Palette.surfaceBorder, lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Palette.textSecondary)
            Text("No layout to preview")
                .font(Typography.emptyTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("Select or create a floor plan to inspect it in 3D.")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview("3D Preview") {
    var builder = Editor3DVenueBuilder()
    let venue = builder.venue(for: PreviewLayouts.annyeong())
    return Editor3DPreviewView(venue: venue)
        .frame(width: 720, height: 480)
        .preferredColorScheme(.dark)
}

#Preview("Empty State") {
    Editor3DPreviewView(venue: nil)
        .frame(width: 720, height: 480)
        .preferredColorScheme(.dark)
}
