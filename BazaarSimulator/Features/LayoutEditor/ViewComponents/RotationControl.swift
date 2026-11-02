import SwiftUI

struct RotationControl: View {
    @Binding var degrees: Int

    private static let options = [0, 90, 180, 270]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Rotation")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: Spacing.m) {
                Menu {
                    ForEach(Self.options, id: \.self) { angle in
                        Button("\(angle)°") {
                            degrees = angle
                        }
                    }
                } label: {
                    HStack {
                        Text("\(degrees)°")
                            .font(Typography.body)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.s)
                            .fill(Palette.fieldOnSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.s)
                            .stroke(Palette.fieldOnSurfaceBorder, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)

                Button {
                    degrees = (degrees + 90) % 360
                } label: {
                    ZStack {
                        Circle()
                            .fill(Palette.fieldOnSurface)
                            .overlay(
                                Circle().stroke(Palette.fieldOnSurfaceBorder, lineWidth: 1)
                            )
                        Image(systemName: "rotate.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rotate 90 degrees")
            }
        }
    }
}
