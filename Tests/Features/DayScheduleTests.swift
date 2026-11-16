import Testing
@testable import BazaarSimulator

@Suite
struct DayScheduleTests {
    private func parameters(hours: TimeRange = TimeRange(startMinute: 10 * 60, endMinute: 21 * 60)) -> EventParameters {
        EventParameters(
            totalVisitors: 5000,
            eventHours: hours,
            bazaarTypeID: "one",
            mix: VisitorMix(equalSplitOf: ["a", "b"])
        )
    }

    @Test("Without a measured busiest time the schedule uses the middle of the event")
    func middleOfTheEvent() {
        let schedule = DaySchedule(parameters: parameters())
        #expect(schedule.peakText == "15:25")
        #expect(schedule.windowMinutes == 10)
    }

    @Test("Event hours set the sample hours, every 2 hours, with the end added when a full hour past")
    func sampleHoursFollowEventHours() {
        let schedule = DaySchedule(parameters: parameters(), peakMinute: 14 * 60)
        #expect(schedule.sampleHours == [10, 12, 14, 16, 18, 20, 21])
        let short = parameters(hours: TimeRange(startMinute: 10 * 60, endMinute: 18 * 60))
        #expect(DaySchedule(parameters: short, peakMinute: 14 * 60).sampleHours == [10, 12, 14, 16, 18])
    }

    @Test("The busiest time the simulation found is the schedule's, and it is a sample hour")
    func peakFromTheSimulation() {
        let schedule = DaySchedule(parameters: parameters(), peakMinute: 16 * 60)
        #expect(schedule.peakText == "16:00")
        #expect(schedule.sampleHours.contains(16))
    }

    @Test("A busiest time that starts off the 2 hour grid is still a sample hour")
    func offGridPeak() {
        let schedule = DaySchedule(parameters: parameters(), peakMinute: 15 * 60)
        #expect(schedule.sampleHours == [10, 12, 14, 15, 16, 18, 20, 21])
    }

    @Test("A busiest time outside the event is moved inside it")
    func peakOutsideEvent() {
        #expect(DaySchedule(parameters: parameters(), peakMinute: 6 * 60).peakText == "10:00")
    }

    @Test("The busiest window always fits before closing")
    func windowFits() {
        #expect(DaySchedule(parameters: parameters(), peakMinute: 20 * 60 + 55).peakText == "20:50")
    }

    @Test("Hours with no length fall back to the simulator's event hours")
    func invalidHours() {
        let broken = parameters(hours: TimeRange(startMinute: 600, endMinute: 600))
        #expect(DaySchedule(parameters: broken, peakMinute: 14 * 60).sampleHours == [10, 12, 14, 16, 18])
    }

    @Test("The window is the busiest time plus the window length")
    func window() {
        let schedule = DaySchedule(parameters: parameters(), peakMinute: 14 * 60)
        #expect(schedule.window == TimeRange(startMinute: 14 * 60, endMinute: 14 * 60 + 10))
    }
}
