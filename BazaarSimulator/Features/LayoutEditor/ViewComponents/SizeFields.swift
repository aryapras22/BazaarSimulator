import SwiftUI

struct SizeFields: View {
    @Binding var width: Double
    @Binding var length: Double
    let range: ClosedRange<Double>
    var showsSingleDimension: Bool = false
    var primaryTitle: String = "Size"
    var detailText: String? = "(width x length)"

    @State private var widthText = ""
    @State private var lengthText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Text(primaryTitle)
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Palette.textPrimary)
                if let detailText, !showsSingleDimension {
                    Text(detailText)
                        .font(Typography.inspectorLabelDetail)
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            HStack(spacing: Spacing.s) {
                TextField("Width", text: $widthText)
                    .textFieldStyle(FieldOnSurfaceStyle(isInvalid: !range.contains(width)))
                    .onChange(of: widthText) { _, newValue in
                        if let parsed = Double(newValue) {
                            width = (parsed * 10.0).rounded() / 10.0
                        } else {
                            width = -1
                        }
                    }

                if !showsSingleDimension {
                    Text("×")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)

                    TextField("Length", text: $lengthText)
                        .textFieldStyle(FieldOnSurfaceStyle(isInvalid: !range.contains(length)))
                        .onChange(of: lengthText) { _, newValue in
                            if let parsed = Double(newValue) {
                                length = (parsed * 10.0).rounded() / 10.0
                            } else {
                                length = -1
                            }
                        }
                }

                Text("m")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .onAppear {
            syncTextFromValues()
        }
        .onChange(of: width) { _, newValue in
            if newValue >= 0, Double(widthText) != newValue {
                widthText = Self.format(newValue)
            }
        }
        .onChange(of: length) { _, newValue in
            if newValue >= 0, Double(lengthText) != newValue {
                lengthText = Self.format(newValue)
            }
        }
    }

    private func syncTextFromValues() {
        widthText = Self.format(width)
        lengthText = Self.format(length)
    }

    private static func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 1e-4 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}
