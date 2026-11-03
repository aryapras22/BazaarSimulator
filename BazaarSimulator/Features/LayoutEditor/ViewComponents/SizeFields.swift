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
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case width
        case length
    }

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
                    .focused($focusedField, equals: .width)
                    .onChange(of: widthText) { _, newValue in
                        guard focusedField == .width, DimensionInput.changesValue(newValue, current: width) else {
                            return
                        }
                        width = DimensionInput.value(from: newValue) ?? -1
                    }

                if !showsSingleDimension {
                    Text("×")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)

                    TextField("Length", text: $lengthText)
                        .textFieldStyle(FieldOnSurfaceStyle(isInvalid: !range.contains(length)))
                        .focused($focusedField, equals: .length)
                        .onChange(of: lengthText) { _, newValue in
                            guard focusedField == .length, DimensionInput.changesValue(newValue, current: length) else {
                                return
                            }
                            length = DimensionInput.value(from: newValue) ?? -1
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
            guard focusedField != .width, newValue >= 0 else { return }
            widthText = DimensionInput.text(for: newValue)
        }
        .onChange(of: length) { _, newValue in
            guard focusedField != .length, newValue >= 0 else { return }
            lengthText = DimensionInput.text(for: newValue)
        }
    }

    private func syncTextFromValues() {
        widthText = DimensionInput.text(for: width)
        lengthText = DimensionInput.text(for: length)
    }
}
