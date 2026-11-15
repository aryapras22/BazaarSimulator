import SwiftUI

struct SimulationInfoPanel: View {
    static let width: CGFloat = 293.5

    let layoutName: String
    let visitorsInside: Int
    let mode: SimulationMode
    let visitorTypes: [VisitorType]

    private static let inset: CGFloat = 16

    @State private var showsGradeRanges = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(layoutName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                    Text("\(visitorsInside) people")
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundStyle(.textSecondary)
                .accessibilityElement(children: .combine)
                .help("People inside right now")
            }
            .frame(height: 20)

            Group {
                switch mode {
                case .congestion: congestionLegend
                case .density: scaleLegend(labels: ["Calm", "Crowded", "Jammed"])
                case .footfall: scaleLegend(labels: ["Rarely walked", "", "Most walked"])
                }
            }
            .padding(.top, 13)

            Text("Visitor types")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textSecondary)
                .padding(.top, 20)

            LazyVGrid(
                columns: [GridItem(.fixed(141.8), spacing: 0, alignment: .leading),
                          GridItem(.fixed(141.8), spacing: 0, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Array(visitorTypes.enumerated()), id: \.element.id) { index, type in
                    legendItem(name: type.name, color: Palette.visitorSeriesColors[index % Palette.visitorSeriesColors.count])
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, Self.inset)
        .padding(.top, 16.5)
        .padding(.bottom, 12.5)
        .frame(width: Self.width, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            shape
                .fill(Color(hex: 0x2E405C))
                .overlay { shape.strokeBorder(Color(hex: 0x4A5D78).opacity(0.8), lineWidth: 1) }
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: showsGradeRanges)
    }

    private func scaleLegend(labels: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LinearGradient(colors: HeatScale.colors, startPoint: .leading, endPoint: .trailing)
                .frame(height: 7)
                .clipShape(Capsule())
            ZStack {
                Text(labels[0]).frame(maxWidth: .infinity, alignment: .leading)
                Text(labels[1]).frame(maxWidth: .infinity, alignment: .center)
                Text(labels[2]).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.textSecondary)
            .frame(height: 14)
            .padding(.top, 6.5)
        }
        .accessibilityElement(children: .combine)
    }

    private var congestionLegend: some View {
        VStack(alignment: .leading, spacing: 0) {
            SeverityScaleView(labelBelow: true, cellWidth: 40, barHeight: 26, barRadius: 8, labelSpacing: 5, letterSize: 11.5)

            Button {
                showsGradeRanges.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(showsGradeRanges ? "Hide what the grades mean" : "What do the grades mean?")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(showsGradeRanges ? 180 : 0))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0x82A9DC))
                .frame(height: 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)

            if showsGradeRanges {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(SeverityGrade.allCases) { grade in
                        HStack(alignment: .top, spacing: 12) {
                            Text(grade.letter)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(grade.color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(grade.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.textPrimary)
                                Text(grade.meaning)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
    }

    private func legendItem(name: String, color: Color) -> some View {
        HStack(spacing: 10.5) {
            Circle()
                .fill(color)
                .frame(width: 13, height: 13)
            Text(name)
                .font(.system(size: 12.25, weight: .bold))
                .foregroundStyle(.textPrimary)
                .fixedSize()
        }
        .frame(width: 141.8, height: 18, alignment: .leading)
    }
}

