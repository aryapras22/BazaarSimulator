import SwiftUI

/// One selectable peak hours slot. Dimmed and inert while peak hours are off.
struct PeakChip: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(Typography.body.monospacedDigit())
                .foregroundColor(foreground)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(RoundedRectangle(cornerRadius: Radius.s).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        isEnabled ? Palette.textPrimary : Palette.textDisabled
    }

    private var fill: Color {
        guard isEnabled else { return Palette.controlDisabled }
        return isSelected ? Palette.accentMuted : Palette.fieldOnSurface
    }

    private var border: Color {
        guard isEnabled else { return Palette.surfaceDisabledBorder }
        return isSelected ? Palette.accent : Palette.fieldOnSurfaceBorder
    }
}

#Preview("States") {
    HStack {
        PeakChip(title: "08:00 - 10:00", isSelected: false, isEnabled: true, onTap: {})
        PeakChip(title: "10:00 - 12:00", isSelected: true, isEnabled: true, onTap: {})
        PeakChip(title: "12:00 - 14:00", isSelected: false, isEnabled: false, onTap: {})
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
