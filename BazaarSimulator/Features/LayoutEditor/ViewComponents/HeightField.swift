import SwiftUI

struct HeightField: View {
    @Binding var height: Double
    let range: ClosedRange<Double> = 0.1...10.0

    @State private var heightText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Height")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: Spacing.s) {
                TextField("Height", text: $heightText)
                    .textFieldStyle(FieldOnSurfaceStyle(isInvalid: !range.contains(height)))
                    .focused($isFocused)
                    .onChange(of: heightText) { _, newValue in
                        guard isFocused, DimensionInput.changesValue(newValue, current: height) else { return }
                        height = DimensionInput.value(from: newValue) ?? -1
                    }

                Text("m")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .onAppear {
            heightText = DimensionInput.text(for: height)
        }
        .onChange(of: height) { _, newValue in
            guard !isFocused, newValue >= 0 else { return }
            heightText = DimensionInput.text(for: newValue)
        }
    }
}
