import SwiftUI

struct CanvasCursorReadout: View {
    let pointer: CanvasPointer

    var body: some View {
        if let world = pointer.world {
            Text(readout(for: world))
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs + 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(Palette.surface.opacity(0.8))
                )
        }
    }

    private func readout(for world: SIMD2<Double>) -> String {
        let position = "x \(String(format: "%.1f", world.x)) m, y \(String(format: "%.1f", world.y)) m"
        guard let description = pointer.hitDescription else { return position }
        return "\(position) · \(description)"
    }
}

#Preview("Readout over a booth, a door, and empty floor") {
    VStack(alignment: .leading, spacing: Spacing.l) {
        ForEach(
            ["Booth A-12 · Fashion · 2.5 × 2.5 m", "Door A · Entrance · 3.5 m", "Floor"],
            id: \.self
        ) { description in
            CanvasCursorReadout(pointer: previewPointer(description))
        }
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

@MainActor
private func previewPointer(_ description: String) -> CanvasPointer {
    let pointer = CanvasPointer()
    pointer.world = SIMD2<Double>(31.4, 42.3)
    pointer.hitDescription = description
    return pointer
}
