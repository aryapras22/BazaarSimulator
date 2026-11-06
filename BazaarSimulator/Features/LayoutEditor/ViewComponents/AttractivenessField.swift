import SwiftUI

struct AttractivenessField: View {
    static let range: ClosedRange<Double> = 0...10

    @Binding var value: Double

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Attractiveness")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            TextField("Attractiveness", text: $text)
                .textFieldStyle(FieldOnSurfaceStyle(isInvalid: !Self.range.contains(value)))
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    guard isFocused, DimensionInput.changesValue(newValue, current: value) else { return }
                    value = DimensionInput.value(from: newValue) ?? -1
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
}
