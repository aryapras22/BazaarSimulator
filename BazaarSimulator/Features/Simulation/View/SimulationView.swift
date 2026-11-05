import SwiftUI

/// Main container view for the 3D venue simulation viewer.
/// Embeds the SceneKit 3D scene with an overlay showing layout info and controls.
struct SimulationView: View {
    let layout: Layout
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack(alignment: .top) {
            // 3D SceneKit viewport
            Simulation3DSceneView(layout: layout)
                .ignoresSafeArea()

            // Top HUD overlay
            headerOverlay
                .padding(.top, Spacing.m)
                .padding(.horizontal, Spacing.l)
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private var headerOverlay: some View {
        HStack(spacing: Spacing.m) {
            // Layout info badge
            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name.isEmpty ? "3D Venue" : layout.name)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)

                let dimensions = "\(Int(layout.sizeM.x))m × \(Int(layout.sizeM.y))m"
                let boothCount = layout.objects.filter { $0.kind == .booth }.count
                Text("\(dimensions) · \(boothCount) booths")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Palette.surface.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(Palette.surfaceBorder, lineWidth: 1)
            )

            Spacer()

            // Camera tips pill
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

            // Optional dismiss button
            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(Palette.surface.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close 3D View")
            }
        }
    }
}

#Preview("Small Market") {
    SimulationView(layout: PreviewLayouts.smallMarket())
}

#Preview("Beyond Market") {
    SimulationView(layout: PreviewLayouts.beyond())
}
