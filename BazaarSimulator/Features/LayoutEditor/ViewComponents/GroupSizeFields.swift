import SwiftUI

struct GroupSizeFields: View {
    @Binding var draft: GroupInspectorDraft
    let width: MixedValue<Double>
    let length: MixedValue<Double>
    let range: ClosedRange<Double>

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
                Text("Size")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Palette.textPrimary)
                Text("(width x length)")
                    .font(Typography.inspectorLabelDetail)
                    .foregroundStyle(Palette.textSecondary)
            }

            HStack(spacing: Spacing.s) {
                TextField("Mixed", text: $widthText)
                    .textFieldStyle(FieldOnSurfaceStyle(isInvalid: isInvalid(draft.widthM)))
                    .focused($focusedField, equals: .width)
                    .onChange(of: widthText) { _, newValue in
                        guard focusedField == .width else { return }
                        draft.widthM = change(for: newValue)
                    }

                Text("×")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)

                TextField("Mixed", text: $lengthText)
                    .textFieldStyle(FieldOnSurfaceStyle(isInvalid: isInvalid(draft.lengthM)))
                    .focused($focusedField, equals: .length)
                    .onChange(of: lengthText) { _, newValue in
                        guard focusedField == .length else { return }
                        draft.lengthM = change(for: newValue)
                    }

                Text("m")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .onAppear { syncText() }
        .onChange(of: width) { _, _ in
            if focusedField != .width { widthText = text(for: width) }
        }
        .onChange(of: length) { _, _ in
            if focusedField != .length { lengthText = text(for: length) }
        }
    }

    private func syncText() {
        widthText = text(for: width)
        lengthText = text(for: length)
    }

    private func text(for value: MixedValue<Double>) -> String {
        guard case .shared(let shared) = value else { return "" }
        return DimensionInput.text(for: shared)
    }

    private func change(for text: String) -> FieldChange<Double> {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return .unchanged }
        return .set(DimensionInput.value(from: text) ?? -1)
    }

    private func isInvalid(_ change: FieldChange<Double>) -> Bool {
        guard case .set(let value) = change else { return false }
        return !range.contains(value)
    }
}
