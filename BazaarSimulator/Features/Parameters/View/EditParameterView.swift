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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                totalVisitorsSection
                Divider()
                eventDurationSection
                Divider()
                peakHoursSection
                Divider()
                bazaarTypeSection
                visitorTypeSection
                Divider()
                groupSizeSection
                actionButtonsSection
            }
            .padding(24)
        }
        .frame(width: 680, height: 640)
        .background(Palette.background)
        .onAppear(perform: loadFromSession)
        .onChange(of: bazaarType) { _, newType in applyBazaarPreset(newType) }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Parameter").font(Typography.title).foregroundStyle(Palette.textPrimary)
            Text("Applies to every layout in this project")
                .font(Typography.subtitle).foregroundStyle(Palette.textSecondary)
        }
        .padding(.bottom, 6)
    }

    private var totalVisitorsSection: some View {
        formRow(title: "Total Visitors", subtitle: "Estimated number of visitors per day.") {
            HStack(spacing: 8) {
                TextField("", value: $totalVisitors, format: .number)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 60)
                Text("people").font(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.surfaceBorder, lineWidth: 1))
        }
    }

    private var eventDurationSection: some View {
        formRow(title: "Event Duration", subtitle: "Set number of hours the event per day.") {
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(peakPeriods, id: \.self) { period in
                    peakPeriodPill(period)
                }
                addPeakPeriodButton
            }
            .frame(maxWidth: 380)
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
        formRow(title: "Bazaar Type", subtitle: "Set bazaar type.") {
            Picker("", selection: $bazaarType) {
                Text("Family & Kids").tag("Family & Kids")
                Text("Culinary / Food").tag("Culinary / Food")
                Text("Fashion & Local Brand").tag("Fashion & Local Brand")
            }
            .pickerStyle(.menu)
            .frame(width: 190)
        }
    }

    private var visitorTypeSection: some View {
        formRow(title: "Visitor Type", subtitle: "Set the proportion of each type.") {
            VStack(alignment: .leading, spacing: 12) {
                proportionBar
                VStack(spacing: 10) {
                    visitorSliderRow("Socializer", "Buys and stays longer.", shareBinding(for: 0), $socializerLocked, .blue)
                    Divider()
                    visitorSliderRow("Family Member", "Moves slow and in group.", shareBinding(for: 1), $familyMemberLocked, .teal)
                    Divider()
                    visitorSliderRow("Stroller", "Moves around leisurely.", shareBinding(for: 2), $strollerLocked, .orange)
                    Divider()
                    visitorSliderRow("Purpose Buyer", "Quick and straightforward.", shareBinding(for: 3), $purposeBuyerLocked, .purple)
                }
                Text("Lock a type to keep it fixed.")
                    .font(Typography.caption).foregroundStyle(Palette.textSecondary).padding(.top, 4)
            }
            .frame(maxWidth: 420)
        }
    }

    private var groupSizeSection: some View {
        formRow(title: "Group Size", subtitle: "Set max amount in each group.") {
            Picker("", selection: $maxGroupSize) {
                ForEach(1...10, id: \.self) { size in Text("\(size)").tag(size) }
            }
            .pickerStyle(.menu).frame(width: 80)
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
        .padding(.top, 16)
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
        let rawTotal = Int((socializerVal + familyMemberVal + strollerVal + purposeBuyerVal).rounded())
        return VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 1) {
                    segmentBox(value: socializerVal, width: geo.size.width, color: .blue)
                    segmentBox(value: familyMemberVal, width: geo.size.width, color: .teal)
                    segmentBox(value: strollerVal, width: geo.size.width, color: .orange)
                    segmentBox(value: purposeBuyerVal, width: geo.size.width, color: .purple)
                    Spacer(minLength: 0)
                }
                .background(Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 28)

            HStack {
                Text("Total").font(Typography.caption).foregroundStyle(Palette.textSecondary)
                Spacer()
                Text("\(rawTotal)%")
                    .font(Typography.caption)
                    .foregroundStyle(rawTotal == 100 ? Color.green : Color.orange)
            }
        }
    }

    @ViewBuilder
    private func segmentBox(value: Double, width: CGFloat, color: Color) -> some View {
        if value > 0 {
            let pct = Int(value.rounded())
            Rectangle()
                .fill(color.opacity(0.8))
                .frame(width: max(20, width * CGFloat(value / 100.0)))
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
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Typography.body).foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(Typography.caption).foregroundStyle(Palette.textSecondary)
            }
            .frame(width: 145, alignment: .leading)

            Spacer(minLength: 5)
            Slider(value: value, in: 0...100, step: 1).disabled(isLocked.wrappedValue)

            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 36, height: 24)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.surfaceBorder, lineWidth: 1))

            Button {
                isLocked.wrappedValue.toggle()
            } label: {
                Image(systemName: isLocked.wrappedValue ? "lock.fill" : "lock.open")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
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
        for idx in 0..<4 where !locked[idx] {
            shares[idx] = 0
        }
        for idx in 0..<4 where !locked[idx] {
            shares = VisitorShareBalancer.adjust(shares: shares, locked: locked, changedIndex: idx, newValue: target[idx])
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
