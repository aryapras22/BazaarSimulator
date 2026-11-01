import SwiftUI

struct PlanRowStatusView: View {
    let status: PlanRowDisplay.Status

    var body: some View {
        switch status {
        case .done(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundColor(Palette.accentText)
        case .reading(let progress):
            HStack(spacing: Spacing.s) {
                Text("Reading...")
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)

                ProgressBar(value: progress)
                    .frame(width: 64, height: 4)
            }
        case .waiting(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundColor(Palette.textSecondary)
        case .failed(let message):
            Text(message)
                .font(Typography.caption)
                .foregroundColor(Palette.destructive)
        case .cancelled(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundColor(Palette.textSecondary)
        }
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: Spacing.m) {
        PlanRowStatusView(status: .done(text: "✓ 66 booths · 3 doors"))
        PlanRowStatusView(status: .reading(progress: 0.4))
        PlanRowStatusView(status: .waiting(text: "Waiting..."))
        PlanRowStatusView(status: .failed(message: "Couldn't read this plan"))
        PlanRowStatusView(status: .cancelled(text: "Cancelled"))
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}
