import SwiftUI

struct CanvasBackgroundMenu: View {
    @Binding var selection: CanvasBackground

    var body: some View {
        Menu {
            Picker("Canvas background", selection: $selection) {
                ForEach(CanvasBackground.allCases) { background in
                    Text(background.title).tag(background)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: "paintpalette")
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.surface))
                .overlay(Circle().stroke(Palette.surfaceBorder, lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Canvas background")
        .accessibilityLabel("Canvas background")
    }
}

#Preview {
    CanvasBackgroundMenu(selection: .constant(.autoCAD))
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}
