import SwiftUI

/// A floor plan shown larger, over the page: the layout with the edits made in the editor and each booth in its
/// category's color, with zoom buttons and a close button.
struct LayoutPreviewDialog: View {
    let layout: Layout
    /// Colors each booth by its category.
    var legend: Legend?
    let dismiss: () -> Void

    @State private var zoom: CGFloat = 1

    private var plan: PlanFrame { PlanFrame(origin: .zero, size: layout.sizeM) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack {
                Text("Preview")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Palette.textPrimary)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Palette.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Palette.control))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close preview")
            }

            ZoomablePlan(zoom: $zoom) {
                LayoutPlanCanvas(layout: layout, plan: plan, legend: legend)
                    .equatable()
            }
            .aspectRatio(planAspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: Spacing.s) {
                    zoomButton("plus", label: "Zoom in", disabled: zoom >= PlanZoom.range.upperBound) {
                        zoom = PlanZoom.clamp(zoom * PlanZoom.step)
                    }
                    zoomButton("minus", label: "Zoom out", disabled: zoom <= PlanZoom.range.lowerBound) {
                        zoom = PlanZoom.clamp(zoom / PlanZoom.step)
                    }
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassModalSurface()
        .accessibilityElement(children: .contain)
    }

    private var planAspect: CGFloat {
        layout.sizeM.y > 0 ? CGFloat(layout.sizeM.x / layout.sizeM.y) : 1
    }

    private func zoomButton(_ symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.textPrimary.opacity(disabled ? 0.35 : 1))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.control))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

extension View {
    /// Shows a layout preview over this view, with the rest dimmed.
    func layoutPreview(
        _ layout: Layout?, legend: Legend? = nil, onDismiss: @escaping () -> Void
    ) -> some View {
        // What is behind the preview is blurred, as behind Insights.
        blur(radius: layout == nil ? 0 : 14)
        .overlay {
            if let shown = layout {
                ZStack {
                    Palette.scrim
                        .ignoresSafeArea()
                        .onTapGesture(perform: onDismiss)
                    // Nearly the whole window, the page still showing around it.
                    LayoutPreviewDialog(layout: shown, legend: legend, dismiss: onDismiss)
                        .padding(Spacing.xl)
                        .padding(.top, Spacing.xl)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: layout?.id)
    }
}
