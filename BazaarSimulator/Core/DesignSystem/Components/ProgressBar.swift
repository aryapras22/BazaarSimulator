import SwiftUI

struct ProgressBar: View {
    let value: Double?

    @State private var indeterminateOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.s)
                    .fill(Palette.controlOnSurface)

                if let value {
                    let clamped = min(max(value, 0.0), 1.0)
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(Palette.accent)
                        .frame(width: geometry.size.width * CGFloat(clamped))
                } else {
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(Palette.accent)
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: geometry.size.width * indeterminateOffset)
                        .onAppear {
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                indeterminateOffset = 1.0
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        }
        .frame(height: 4)
    }
}

#Preview("Normal") {
    ProgressBar(value: 0.6)
        .frame(width: 200)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    VStack(alignment: .leading, spacing: Spacing.xs) {
        Text("Reading floor plan at high resolution with multiple layout candidates...")
            .font(Typography.caption)
        ProgressBar(value: 0.4)
    }
    .frame(width: 300)
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    ProgressBar(value: nil)
        .frame(width: 200)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    ProgressBar(value: 0.9)
        .frame(width: 200)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    ProgressBar(value: 0.2)
        .disabled(true)
        .frame(width: 200)
        .padding()
        .preferredColorScheme(.dark)
}
