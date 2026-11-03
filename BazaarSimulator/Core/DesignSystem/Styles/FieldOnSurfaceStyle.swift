import SwiftUI

struct FieldOnSurfaceStyle: TextFieldStyle {
    var isInvalid: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(Typography.body)
            .foregroundStyle(isEnabled ? Palette.textPrimary : Palette.textDisabled)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.s)
                    .fill(isEnabled ? Palette.fieldOnSurface : Palette.controlDisabled)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s)
                    .stroke(
                        isInvalid ? Palette.destructive : Palette.fieldOnSurfaceBorder,
                        lineWidth: 1
                    )
            )
    }
}

#Preview("Normal") {
    @Previewable @State var text = "2.5"
    TextField("Width", text: $text)
        .textFieldStyle(FieldOnSurfaceStyle())
        .frame(width: 120)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    @Previewable @State var text = "Main Entrance Near Food Court Area"
    TextField("Label", text: $text)
        .textFieldStyle(FieldOnSurfaceStyle())
        .frame(width: 220)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    @Previewable @State var text = ""
    TextField("Width", text: $text)
        .textFieldStyle(FieldOnSurfaceStyle())
        .frame(width: 120)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    @Previewable @State var text = "0.2"
    TextField("Width", text: $text)
        .textFieldStyle(FieldOnSurfaceStyle(isInvalid: true))
        .frame(width: 120)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    @Previewable @State var text = "2.0"
    TextField("Width", text: $text)
        .textFieldStyle(FieldOnSurfaceStyle())
        .disabled(true)
        .frame(width: 120)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}
