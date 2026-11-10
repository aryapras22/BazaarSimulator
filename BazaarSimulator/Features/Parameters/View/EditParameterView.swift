import SwiftUI

/// Modal dialog for editing event and visitor parameters before running the simulation.
/// Based on BazaarSimulationFinal's EditParameterView.
struct EditParameterView: View {
    @Environment(\.dismiss) private var dismiss

    let projectID: UUID
    let session: any ProjectSessionProtocol
    var onApply: (() -> Void)?

    @State private var totalVisitors: Int = 2000
    @State private var startTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()

    @State private var isPeakHoursEnabled: Bool = true
    @State private var peakPeriods: [String] = [
        "08:00 - 10:00", "10:00 - 12:00", "12:00 - 14:00",
        "14:00 - 16:00", "16:00 - 18:00", "18:00 - 20:00"
    ]
    @State private var selectedPeakPeriods: Set<String> = ["12:00 - 14:00", "18:00 - 20:00"]

    @State private var bazaarType: String = "Family & Kids"

    @State private var socializerVal: Double = 21
    @State private var socializerLocked: Bool = false
    @State private var familyMemberVal: Double = 46
    @State private var familyMemberLocked: Bool = false
    @State private var strollerVal: Double = 33
    @State private var strollerLocked: Bool = false
    @State private var purposeBuyerVal: Double = 0
    @State private var purposeBuyerLocked: Bool = false
    @State private var maxGroupSize: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection
            Divider().overlay(Palette.surfaceBorder)
            totalVisitorsSection
            Divider().overlay(Palette.surfaceBorder)
            eventDurationSection
            Divider().overlay(Palette.surfaceBorder)
            peakHoursSection
            Divider().overlay(Palette.surfaceBorder)
            bazaarTypeSection
            visitorTypeSection
            Divider().overlay(Palette.surfaceBorder)
            groupSizeSection
            actionButtonsSection
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .frame(width: 820)
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.background)
        .onAppear(perform: loadFromSession)
        .onChange(of: bazaarType) { _, newType in applyBazaarPreset(newType) }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Parameters")
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text("Applies to every layout in this project")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.bottom, 2)
    }

    private var totalVisitorsSection: some View {
        formRow(title: "Total Visitors", subtitle: "Estimated number of visitors per day.") {
            HStack(spacing: 8) {
                TextField("", value: $totalVisitors, format: .number)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 68)
                Text("people").font(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.surfaceBorder, lineWidth: 1))
        }
    }

    private var eventDurationSection: some View {
        formRow(title: "Event Duration", subtitle: "Set start and end hours for the event.") {
            HStack(spacing: 12) {
                timePickerPill(selection: $startTime, label: "start")
                timePickerPill(selection: $endTime, label: "end")
            }
        }
    }

    private var peakHoursSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Peak Hours Period")
                        .font(Typography.fieldLabel)
                        .foregroundStyle(Palette.textPrimary)
                    Toggle("", isOn: $isPeakHoursEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                Text("Select one or more peak hours periods.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ForEach(peakPeriods, id: \.self) { period in
                    peakPeriodPill(period)
                }
                if !peakPeriods.contains("20:00 - 22:00") {
                    addPeakPeriodButton
                }
            }
            .frame(width: 520)
        }
    }

    private func peakPeriodPill(_ period: String) -> some View {
        let isSelected = selectedPeakPeriods.contains(period) && isPeakHoursEnabled
        return Button {
            guard isPeakHoursEnabled else { return }
            if selectedPeakPeriods.contains(period) {
                selectedPeakPeriods.remove(period)
            } else {
                selectedPeakPeriods.insert(period)
            }
        } label: {
            Text(period)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? Palette.accent.opacity(0.35) : Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Palette.accent : Palette.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var addPeakPeriodButton: some View {
        Button {
            let nextSlot = "20:00 - 22:00"
            if !peakPeriods.contains(nextSlot) {
                peakPeriods.append(nextSlot)
                selectedPeakPeriods.insert(nextSlot)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 32, height: 28)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var bazaarTypeSection: some View {
        formRow(title: "Bazaar Type", subtitle: "Select a preset visitor mix.") {
            Picker("", selection: $bazaarType) {
                Text("Family & Kids").tag("Family & Kids")
                Text("Culinary / Food").tag("Culinary / Food")
                Text("Fashion & Local Brand").tag("Fashion & Local Brand")
            }
            .pickerStyle(.menu)
            .frame(width: 210)
        }
    }

    private var visitorTypeSection: some View {
        formRow(title: "Visitor Type", subtitle: "Adjust the share of each persona.\nLock a type to keep it fixed.") {
            VStack(alignment: .leading, spacing: 10) {
                proportionBar
                VStack(spacing: 8) {
                    visitorSliderRow("Socializer", "Buys and stays longer.", shareBinding(for: 0), $socializerLocked, .blue)
                    Divider().overlay(Palette.surfaceBorder.opacity(0.6))
                    visitorSliderRow("Family Member", "Moves slow and in group.", shareBinding(for: 1), $familyMemberLocked, .teal)
                    Divider().overlay(Palette.surfaceBorder.opacity(0.6))
                    visitorSliderRow("Stroller", "Moves around leisurely.", shareBinding(for: 2), $strollerLocked, .orange)
                    Divider().overlay(Palette.surfaceBorder.opacity(0.6))
                    visitorSliderRow("Purpose Buyer", "Quick and straightforward.", shareBinding(for: 3), $purposeBuyerLocked, .purple)
                }
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.surfaceBorder, lineWidth: 1))
            }
            .frame(width: 520)
        }
    }

    private var groupSizeSection: some View {
        formRow(title: "Group Size", subtitle: "Maximum visitors in a single group.") {
            Picker("", selection: $maxGroupSize) {
                ForEach(1...10, id: \.self) { size in Text("\(size)").tag(size) }
            }
            .pickerStyle(.menu).frame(width: 90)
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel") { dismiss() }.buttonStyle(.secondary).keyboardShortcut(.cancelAction)
            Button("Apply") {
                saveAndRunSimulation()
                dismiss()
                onApply?()
            }
            .buttonStyle(.primary).keyboardShortcut(.defaultAction)
        }
        .padding(.top, 8)
    }

    // MARK: - Subcomponents & Helpers

    private func formRow<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typography.fieldLabel).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            content()
        }
    }

    private func timePickerPill(selection: Binding<Date>, label: String) -> some View {
        HStack(spacing: 8) {
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
            Text(label).font(Typography.caption).foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.surfaceBorder, lineWidth: 1))
    }

    private var proportionBar: some View {
        let sum = max(1.0, socializerVal + familyMemberVal + strollerVal + purposeBuyerVal)
        return GeometryReader { geo in
            HStack(spacing: 1) {
                segmentBox(value: socializerVal, sum: sum, width: geo.size.width, color: .blue)
                segmentBox(value: familyMemberVal, sum: sum, width: geo.size.width, color: .teal)
                segmentBox(value: strollerVal, sum: sum, width: geo.size.width, color: .orange)
                segmentBox(value: purposeBuyerVal, sum: sum, width: geo.size.width, color: .purple)
            }
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private func segmentBox(value: Double, sum: Double, width: CGFloat, color: Color) -> some View {
        if value > 0 {
            let pct = Int(value.rounded())
            Rectangle()
                .fill(color.opacity(0.85))
                .frame(width: max(24, width * CGFloat(value / sum)))
                .overlay(Text("\(pct)%").font(.caption2.bold()).foregroundStyle(.white))
        }
    }

    private func visitorSliderRow(
        _ title: String,
        _ subtitle: String,
        _ value: Binding<Double>,
        _ isLocked: Binding<Bool>,
        _ color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Typography.body).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            .frame(width: 145, alignment: .leading)

            Slider(value: value, in: 0...100, step: 1)
                .disabled(isLocked.wrappedValue)
                .frame(maxWidth: .infinity)

            Text("\(Int(value.wrappedValue.rounded()))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 44, height: 24)
                .background(Palette.background, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.surfaceBorder, lineWidth: 1))

            Button {
                isLocked.wrappedValue.toggle()
            } label: {
                Image(systemName: isLocked.wrappedValue ? "lock.fill" : "lock.open")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isLocked.wrappedValue ? Palette.accentIcon : Palette.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }

    private func shareBinding(for index: Int) -> Binding<Double> {
        Binding(
            get: { [socializerVal, familyMemberVal, strollerVal, purposeBuyerVal][index] },
            set: { newValue in
                let adjusted = VisitorShareBalancer.adjust(
                    shares: [socializerVal, familyMemberVal, strollerVal, purposeBuyerVal],
                    locked: [socializerLocked, familyMemberLocked, strollerLocked, purposeBuyerLocked],
                    changedIndex: index,
                    newValue: newValue
                )
                socializerVal = adjusted[0]
                familyMemberVal = adjusted[1]
                strollerVal = adjusted[2]
                purposeBuyerVal = adjusted[3]
            }
        )
    }

    private func loadFromSession() {
        let params = session.parameters(for: projectID)
        totalVisitors = params.totalVisitors
        let cal = Calendar.current
        startTime = cal.date(bySettingHour: params.startMinutes / 60, minute: params.startMinutes % 60, second: 0, of: Date()) ?? startTime
        endTime = cal.date(bySettingHour: params.endMinutes / 60, minute: params.endMinutes % 60, second: 0, of: Date()) ?? endTime
        isPeakHoursEnabled = params.isPeakHoursEnabled
        peakPeriods = params.peakPeriods
        selectedPeakPeriods = params.selectedPeakPeriods
        bazaarType = params.bazaarType
        socializerVal = params.socializerPercent
        familyMemberVal = params.familyMemberPercent
        strollerVal = params.strollerPercent
        purposeBuyerVal = params.purposeBuyerPercent
        maxGroupSize = params.maxGroupSize
    }

    private func applyBazaarPreset(_ preset: String) {
        let target: [Double]
        switch preset {
        case "Culinary / Food": target = [30, 25, 30, 15]
        case "Fashion & Local Brand": target = [25, 5, 55, 15]
        default: target = [21, 46, 33, 0]
        }
        let locked = [socializerLocked, familyMemberLocked, strollerLocked, purposeBuyerLocked]
        var shares = [socializerVal, familyMemberVal, strollerVal, purposeBuyerVal]
        let lockedSum = (0..<4).filter { locked[$0] }.reduce(0.0) { $0 + shares[$1] }
        let unlockedIndices = (0..<4).filter { !locked[$0] }
        let unlockedTargetSum = unlockedIndices.reduce(0.0) { $0 + target[$1] }
        let available = max(0.0, 100.0 - lockedSum)

        var assigned = 0.0
        for (offset, idx) in unlockedIndices.enumerated() {
            if offset == unlockedIndices.count - 1 {
                shares[idx] = max(0.0, (available - assigned).rounded())
            } else if unlockedTargetSum > 0 {
                let scaled = (target[idx] / unlockedTargetSum * available).rounded()
                shares[idx] = scaled
                assigned += scaled
            } else {
                let equal = (available / Double(unlockedIndices.count)).rounded()
                shares[idx] = equal
                assigned += equal
            }
        }
        socializerVal = shares[0]
        familyMemberVal = shares[1]
        strollerVal = shares[2]
        purposeBuyerVal = shares[3]
    }

    private func saveAndRunSimulation() {
        let startComps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        let endComps = Calendar.current.dateComponents([.hour, .minute], from: endTime)
        let startMins = (startComps.hour ?? 10) * 60 + (startComps.minute ?? 0)
        let rawEndMins = (endComps.hour ?? 21) * 60 + (endComps.minute ?? 0)
        let updated = EventParameters(
            totalVisitors: totalVisitors,
            startMinutes: startMins,
            endMinutes: rawEndMins > startMins ? rawEndMins : startMins + 60,
            isPeakHoursEnabled: isPeakHoursEnabled,
            peakPeriods: peakPeriods,
            selectedPeakPeriods: selectedPeakPeriods,
            bazaarType: bazaarType,
            socializerPercent: socializerVal,
            familyMemberPercent: familyMemberVal,
            strollerPercent: strollerVal,
            purposeBuyerPercent: purposeBuyerVal,
            maxGroupSize: maxGroupSize
        )
        session.setParameters(updated, for: projectID)
        session.runSimulations(for: projectID)
    }
}
