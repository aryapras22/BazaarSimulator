import SwiftUI

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
