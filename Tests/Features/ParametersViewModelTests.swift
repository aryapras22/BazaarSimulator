import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct ParametersViewModelTests {
    private let catalog = PresetCatalog(
        visitorTypes: [
            VisitorType(id: "a", name: "A", summary: ""), VisitorType(id: "b", name: "B", summary: ""),
            VisitorType(id: "c", name: "C", summary: ""), VisitorType(id: "d", name: "D", summary: "")
        ],
        bazaarTypes: [
            BazaarTypePreset(id: "one", name: "One", totalVisitors: 5000, mix: ["a": 40, "b": 30, "c": 20, "d": 10]),
            BazaarTypePreset(id: "two", name: "Two", totalVisitors: 800, mix: ["a": 10, "b": 10, "c": 10, "d": 70])
        ]
    )

    private func makeModel(closed: @escaping () -> Void = {}) -> (ParametersViewModel, ProjectSession, UUID) {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let model = ParametersViewModel(projectID: project.id, session: session, catalog: catalog, onClose: closed)
        return (model, session, project.id)
    }

    @Test("Starts from the first bazaar type when nothing is stored")
    func defaults() {
        let (model, _, _) = makeModel()
        #expect(model.draft.bazaarTypeID == "one")
        #expect(model.draft.totalVisitors == 5000)
        #expect(model.startText == "10:00")
        #expect(model.endText == "21:00")
    }

    @Test("Picking a bazaar type reseeds the visitor total and the mix")
    func bazaarTypeSeeds() {
        let (model, _, _) = makeModel()
        model.bazaarTypeID = "two"
        #expect(model.draft.totalVisitors == 800)
        #expect(model.mix.share(for: "d")?.percent == 70)
    }

    @Test("Event hours reject a start at or after the end, and bad text")
    func eventHoursValidation() {
        let (model, _, _) = makeModel()
        #expect(model.commitStart("22:00") == "10:00")
        #expect(model.commitEnd("09:00") == "21:00")
        #expect(model.commitStart("nope") == "10:00")
        #expect(model.commitStart("08:30") == "08:30")
        #expect(model.commitEnd("23:00") == "23:00")
    }

    @Test("Total visitors accepts positive whole numbers only")
    func totalVisitors() {
        let (model, _, _) = makeModel()
        #expect(model.commitTotalVisitors("1200") == "1200")
        #expect(model.commitTotalVisitors("0") == "1200")
        #expect(model.commitTotalVisitors("abc") == "1200")
        #expect(model.commitTotalVisitors("99999999") == "1000000")
    }

    @Test("Apply stores the draft and closes")
    func applyStores() {
        var closed = false
        let (model, session, id) = makeModel { closed = true }
        model.setPercent(70, for: "a")
        model.apply()

        let stored = session.eventParameters(for: id)
        #expect(closed)
        #expect(stored?.mix.share(for: "a")?.percent == 70)
    }

    @Test("Cancel closes without storing anything")
    func cancelDiscards() {
        var closed = false
        let (model, session, id) = makeModel { closed = true }
        model.setPercent(70, for: "a")
        model.cancel()
        #expect(closed)
        #expect(session.eventParameters(for: id) == nil)
    }

    @Test("Reopening shows the applied values")
    func reopenRestores() {
        let (model, session, id) = makeModel()
        model.setPercent(70, for: "a")
        model.apply()

        let reopened = ParametersViewModel(projectID: id, session: session, catalog: catalog, onClose: {})
        #expect(reopened.draft.mix.share(for: "a")?.percent == 70)
    }

    @Test("FormCommitScope flushes pending visitor count edits before apply")
    func formCommitScopeFlushesBeforeApply() {
        let (model, session, id) = makeModel()
        let scope = FormCommitScope()
        let fieldID = UUID()
        var draftText = "12500"
        scope.register(id: fieldID) {
            draftText = model.commitTotalVisitors(draftText)
        }
        scope.commitAll()
        model.apply()

        #expect(session.eventParameters(for: id)?.totalVisitors == 12_500)
        #expect(session.resultTabs(for: id).last?.parameters.totalVisitors == 12_500)
    }
}
