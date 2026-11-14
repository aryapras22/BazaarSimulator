import SwiftUI

/// The panel at the top left of the simulator: who is inside, what the colors mean, and the spots.
struct SimulationInfoPanel: View {
    static let width: CGFloat = 293.5
    private static let inset: CGFloat = 16

    let layoutName: String
    let visitorsInside: Int
    let windowText: String
    let mode: SimulationMode
    let progress: Double
    let spots: [SpotOutcome]
    let windowMinutes: Double
    let visitorTypes: [VisitorType]
    var highlightedSpot: Int?
    var footfall: (total: Int, busiest: Int)?

    @State private var showsGradeRanges = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(layoutName) · \(visitorsInside) visitors inside")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(height: 20)
            Text("Busiest window \(windowText)")
                .font(.system(size: 11.5))
                .foregroundStyle(.textMuted)
                .frame(height: 16)
                .padding(.top, 5.5)

            Group {
                switch mode {
                case .congestion: congestionLegend
                case .density:
                    scaleLegend(
                        labels: ["Comfortable", "Stop-and-go", "Jammed"],
                        text: "People per m² of aisle. At 2 per m² each person has about half a square metre."
                    )
                case .footfall: scaleLegend(labels: ["Rarely walked", "", "Most walked"], text: footfallText)
                }
            }
            .padding(.top, 13)

            visitorLegend
                .padding(.top, mode == .congestion ? 21.5 : 17)
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

    private var footfallText: String {
        guard let footfall else { return "How often each path has been walked since the window opened." }
        return "\(footfall.total.formatted()) walks since \(windowText.prefix(5)). The busiest path has been walked \(footfall.busiest.formatted()) times."
    }

    private func scaleLegend(labels: [String], text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            LinearGradient(colors: HeatScale.colors, startPoint: .leading, endPoint: .trailing)
                .frame(height: 7)
                .clipShape(Capsule())
            ZStack {
                Text(labels[0]).frame(maxWidth: .infinity, alignment: .leading)
                Text(labels[1]).frame(maxWidth: .infinity, alignment: .center)
                Text(labels[2]).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 9.5))
            .tracking(0.2)
            .foregroundStyle(.textMuted)
            .frame(height: 12)
            .padding(.top, 6.5)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.textMuted)
                .lineSpacing(-1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
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
                    Text(showsGradeRanges ? "Hide grade ranges" : "Show grade ranges")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(showsGradeRanges ? 180 : 0))
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0x82A9DC))
                .frame(height: 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)

            if showsGradeRanges {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    ForEach(SeverityGrade.allCases) { grade in
                        GridRow {
                            Text(grade.letter)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(grade.color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            Text(grade.rangeText)
                                .font(.system(size: 11))
                                .foregroundStyle(.textMuted)
                                .monospacedDigit()
                            Text(grade.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.textPrimary)
                        }
                        .help(grade.meaning)
                    }
                }
                .padding(.top, 10)
                .transition(.opacity)
            }

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
                .padding(.top, 9.5)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(spots, id: \.number) { spot in
                    spotRow(spot)
                }
            }
            .padding(.top, 11.5)
        }
    }

    private func spotRow(_ spot: SpotOutcome) -> some View {
        let density = spot.density(at: progress)
        let grade = SeverityGrade.grade(forDensity: density)
        let stuck = spot.heavyMinutes(upTo: progress, windowMinutes: windowMinutes)
        return HStack(spacing: 7.5) {
            SpotNumber(number: spot.number)
            VStack(alignment: .leading, spacing: 2.5) {
                Text(spot.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text("\(density.formatted(.number.precision(.fractionLength(1))))/m² · \(spot.visitors(at: progress)) people · stuck \(PlaybackBar.format(stuck * 60))")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.textMuted)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Text("Grade \(grade.letter)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 27.5)
                .background(grade.color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .help("\(grade.title): \(grade.meaning)")
        }
        .frame(height: 32)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(highlightedSpot == spot.number ? 0.1 : 0))
                .padding(-4)
        }
        .animation(.easeOut(duration: 0.15), value: highlightedSpot)
        .accessibilityElement(children: .combine)
    }

    private var visitorLegend: some View {
        let colors = Palette.visitorSeriesColors
        return LazyVGrid(
            columns: [GridItem(.fixed(141.8), spacing: 0, alignment: .leading), GridItem(.fixed(141.8), spacing: 0, alignment: .leading)],
            alignment: .leading,
            spacing: 7
        ) {
            ForEach(Array(visitorTypes.enumerated()), id: \.element.id) { index, type in
                HStack(spacing: 10.5) {
                    Circle()
                        .fill(colors[index % colors.count])
                        .frame(width: 12, height: 12)
                    Text(type.name)
                        .font(.system(size: 12.25, weight: .bold))
                        .foregroundStyle(.textPrimary)
                        .fixedSize()
                }
                .frame(height: 18, alignment: .leading)
            }
        }
    }
}
