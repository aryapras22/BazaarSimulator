
import SwiftUI

enum PlanZoom {
    static let range: ClosedRange<CGFloat> = 1...4
    static let step: CGFloat = 1.5

    static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

struct ZoomablePlan<Content: View>: View {
    @Binding var zoom: CGFloat
    @ViewBuilder let content: Content

    @State private var pinchStart: CGFloat?
    @State private var pan: CGSize = .zero
    @State private var dragStart: CGSize?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            content
                .frame(width: size.width * zoom, height: size.height * zoom)
                .offset(clamped(pan, in: size))
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(pinch)
                .simultaneousGesture(drag(in: size), isEnabled: zoom > 1)
                .onChange(of: zoom, rescalePan)
                .accessibilityZoomAction(zoom(with:))
        }
    }

    private func rescalePan(from old: CGFloat, to new: CGFloat) {
        let ratio = new / old
        pan = new <= 1 ? .zero : CGSize(width: pan.width * ratio, height: pan.height * ratio)
    }

    private func zoom(with action: AccessibilityZoomGestureAction) {
        let factor = action.direction == .zoomIn ? PlanZoom.step : 1 / PlanZoom.step
        zoom = PlanZoom.clamp(zoom * factor)
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? zoom
                pinchStart = start
                zoom = PlanZoom.clamp(start * value.magnification)
            }
            .onEnded { _ in pinchStart = nil }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = dragStart ?? clamped(pan, in: size)
                dragStart = start
                let moved = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
                pan = clamped(moved, in: size)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func clamped(_ offset: CGSize, in size: CGSize) -> CGSize {
        let limitX = size.width * (zoom - 1) / 2, limitY = size.height * (zoom - 1) / 2
        return CGSize(width: min(max(offset.width, -limitX), limitX), height: min(max(offset.height, -limitY), limitY))
    }
}

struct ZoomControls: View {
    @Binding var zoom: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let height = ControlButtonStyle.height

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        HStack(spacing: 0) {
            stepButton("minus", label: "Zoom out", disabled: zoom <= PlanZoom.range.lowerBound) { zoom / PlanZoom.step }
            Button {
                set(1)
            } label: {
                Text("\(Int((zoom * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 46, height: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Show the whole plan")
            .accessibilityLabel("Reset zoom")
            stepButton("plus", label: "Zoom in", disabled: zoom >= PlanZoom.range.upperBound) { zoom * PlanZoom.step }
        }
        .foregroundStyle(Color.textPrimary)
        .frame(height: height)
        .background {
            shape
                .fill(Color.cardButtonFill)
                .overlay { shape.strokeBorder(Color.controlBorder.opacity(0.55), lineWidth: 0.75) }
        }
        .fixedSize()
    }

    private func stepButton(_ symbol: String, label: String, disabled: Bool, value: @escaping () -> CGFloat) -> some View {
        Button {
            set(value())
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .opacity(disabled ? 0.35 : 1)
                .frame(width: 28, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(label)
        .accessibilityLabel(label)
    }

    private func set(_ value: CGFloat) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { zoom = PlanZoom.clamp(value) }
    }
}
