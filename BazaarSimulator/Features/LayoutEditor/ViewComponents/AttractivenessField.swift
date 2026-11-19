import SwiftUI

struct AttractivenessField: View {
    static let range: ClosedRange<Double> = 1...5
    static let sliderStep: Double = 1

    static func isValid(_ value: Double) -> Bool {
        range.contains(value) && value == value.rounded()
    }

    @Binding var value: Double

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Attractiveness")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            HStack(alignment: .top, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Slider(value: sliderValue, in: Self.range, step: Self.sliderStep)
                        .labelsHidden()
                        .tint(.clear)
                        .accessibilityLabel("Attractiveness")
                        .background {
                            Capsule()
                                .fill(AttractivenessScale.gradient)
                                .frame(height: 6)
                        }

                    HStack {
                        Text("Low")
                        Spacer()
                        Text("High")
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                }

                TextField("Attractiveness", text: $text)
                    .textFieldStyle(FieldOnSurfaceStyle(isInvalid: !Self.isValid(value)))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        guard isFocused, DimensionInput.changesValue(newValue, current: value) else { return }
                        value = DimensionInput.value(from: newValue) ?? -1
                    }
            }
        }
        .onAppear {
            text = DimensionInput.text(for: value)
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused, newValue >= 0 else { return }
            text = DimensionInput.text(for: newValue)
        }
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { min(max(value, Self.range.lowerBound), Self.range.upperBound) },
            set: { value = $0 }
        )
    }
}
