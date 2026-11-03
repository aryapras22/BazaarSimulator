import SwiftUI

struct CanvasScaleBar: View {
    let pointsPerMetre: Double

    var body: some View {
        let lengthM = RulerScale.scaleBarLengthM(pointsPerMetre: pointsPerMetre)
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            Text("\(DimensionInput.text(for: lengthM)) m")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            ScaleBarShape()
                .stroke(Palette.textSecondary, lineWidth: 1)
                .frame(width: CGFloat(lengthM * pointsPerMetre), height: 6)
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(Palette.surface.opacity(0.8))
        )
    }
}

private struct ScaleBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview("Scale bar at three scales") {
    VStack(alignment: .trailing, spacing: Spacing.l) {
        CanvasScaleBar(pointsPerMetre: 4)
        CanvasScaleBar(pointsPerMetre: 10)
        CanvasScaleBar(pointsPerMetre: 40)
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
