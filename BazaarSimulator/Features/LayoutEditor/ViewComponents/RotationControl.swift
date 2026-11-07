import SwiftUI

struct RotationControl: View {
    @Binding var degrees: Int
    var isMixed: Bool = false
    var stepDegrees: Int = 90

    private static let mixedTag = -1

    private var options: [Int] {
        Array(stride(from: 0, to: 360, by: stepDegrees))
    }

    private var pickerSelection: Binding<Int> {
        Binding(
            get: { isMixed ? Self.mixedTag : degrees },
            set: { angle in
                if angle != Self.mixedTag { degrees = angle }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Rotation")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: Spacing.m) {
                Picker("Rotation", selection: pickerSelection) {
                    if isMixed {
                        Text("Mixed").tag(Self.mixedTag)
                    }
                    ForEach(options, id: \.self) { angle in
                        Text("\(angle)°").tag(angle)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.large)
                .fixedSize()

                Button {
                    degrees = (degrees + stepDegrees) % 360
                } label: {
                    Label("Rotate \(stepDegrees) degrees", systemImage: "rotate.right")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .help("Rotate \(stepDegrees) degrees")
            }
        }
    }
}
