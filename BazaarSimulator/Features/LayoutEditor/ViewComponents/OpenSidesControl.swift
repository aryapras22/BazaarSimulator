import SwiftUI

struct OpenSidesControl: View {
    @Binding var sides: OpenSides
    var rotationDegrees: Int = 0
    var chip: String?
    var allowsMultiple: Bool = true
    var title: String = "Open Sides"

    @Environment(\.isEnabled) private var isEnabled

    private var screenOpenSides: OpenSides {
        sides.rotatedToScreen(byDegrees: rotationDegrees)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            ZStack {
                RoundedRectangle(cornerRadius: Radius.s)
                    .fill(Palette.diagramFill)
                    .frame(width: 112, height: 112)

                if let chip, !chip.isEmpty {
                    Text(chip)
                        .font(Typography.inspectorLabel)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.s)
                                .fill(Palette.diagramChip)
                        )
                }

                edgeButton(for: .top)
                    .offset(y: -56)
                edgeButton(for: .bottom)
                    .offset(y: 56)
                edgeButton(for: .left)
                    .offset(x: -56)
                edgeButton(for: .right)
                    .offset(x: 56)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 152)

            Text("Red = closed · click an edge to toggle")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder
    private func edgeButton(for screenSide: OpenSides) -> some View {
        let isOpen = screenOpenSides.contains(screenSide)
        let isHorizontal = screenSide == .top || screenSide == .bottom

        Button {
            toggle(screenSide: screenSide)
        } label: {
            ZStack {
                if isHorizontal {
                    HorizontalEdgeLine(isOpen: isOpen)
                        .frame(width: 104, height: 24)
                } else {
                    VerticalEdgeLine(isOpen: isOpen)
                        .frame(width: 24, height: 104)
                }

                if !isOpen {
                    Text("Closed")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.destructive)
                        .offset(
                            x: screenSide == .left ? -24 : (screenSide == .right ? 24 : 0),
                            y: screenSide == .top ? -14 : (screenSide == .bottom ? 14 : 0)
                        )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel(for: screenSide, isOpen: isOpen))
    }

    private func toggle(screenSide: OpenSides) {
        sides = sides.toggling(
            screenSide: screenSide,
            rotationDegrees: rotationDegrees,
            allowsMultiple: allowsMultiple
        )
    }

    private func accessibilityLabel(for screenSide: OpenSides, isOpen: Bool) -> String {
        let sideName: String
        if screenSide == .top {
            sideName = "Top"
        } else if screenSide == .right {
            sideName = "Right"
        } else if screenSide == .bottom {
            sideName = "Bottom"
        } else {
            sideName = "Left"
        }
        return "\(sideName) edge, \(isOpen ? "open" : "closed")"
    }
}

private struct HorizontalEdgeLine: View {
    let isOpen: Bool

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 4, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - 4, y: size.height / 2))
            if isOpen {
                context.stroke(
                    path,
                    with: .color(Palette.diagramChip),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                )
            } else {
                context.stroke(path, with: .color(Palette.destructive), lineWidth: 4)
            }
        }
    }
}

private struct VerticalEdgeLine: View {
    let isOpen: Bool

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width / 2, y: 4))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height - 4))
            if isOpen {
                context.stroke(
                    path,
                    with: .color(Palette.diagramChip),
                    style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                )
            } else {
                context.stroke(path, with: .color(Palette.destructive), lineWidth: 4)
            }
        }
    }
}

#Preview("None Open") {
    @Previewable @State var sides: OpenSides = []
    OpenSidesControl(sides: $sides)
        .frame(width: 290)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Two Open") {
    @Previewable @State var sides: OpenSides = [.right, .bottom]
    OpenSidesControl(sides: $sides)
        .frame(width: 290)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("All Open") {
    @Previewable @State var sides: OpenSides = .all
    OpenSidesControl(sides: $sides)
        .frame(width: 290)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Rotated 90°") {
    @Previewable @State var sides: OpenSides = [.top, .right]
    OpenSidesControl(sides: $sides, rotationDegrees: 90)
        .frame(width: 290)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Stage Single Front") {
    @Previewable @State var sides: OpenSides = .right
    OpenSidesControl(sides: $sides, allowsMultiple: false, title: "Front")
        .frame(width: 290)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    @Previewable @State var sides: OpenSides = [.right, .bottom]
    OpenSidesControl(sides: $sides)
        .disabled(true)
        .frame(width: 290)
        .padding()
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}
