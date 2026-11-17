import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct BackFromEditorTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
    )

    private func setUp() -> (DashboardViewModel, LayoutEditorViewModel) {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(
            ProjectDraft(name: "P", legend: PreviewLayouts.sampleLegend, layouts: [PreviewLayouts.smallMarket()]),
            for: project.id
        )
        let dashboard = DashboardViewModel(
            projectID: project.id, session: session, analysisService: AnalysisService(), catalog: catalog
        )
        return (dashboard, LayoutEditorViewModel(projectID: project.id, session: session))
    }

    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test("Opening the editor and going back without an edit shows the same analysis at once")
    func noEditNoRerun() async throws {
        let (dashboard, editor) = setUp()
        await dashboard.runSimulation()
        #expect(dashboard.phase == .ready)

        editor.refreshDerivedState()
        let booth = try #require(editor.activeLayout?.objects.first { $0.kind == .booth })
        editor.selectObject(booth.id)
        editor.selectObject(nil)

        dashboard.startSimulation()
        await settle()
        #expect(dashboard.phase == .ready)
        #expect(!dashboard.isRunning)
    }

    @Test("An edit that is undone before going back does not run again either")
    func undoneEditNoRerun() async throws {
        let (dashboard, editor) = setUp()
        await dashboard.runSimulation()
        let booth = try #require(editor.activeLayout?.objects.first { $0.kind == .booth })
        editor.selectObject(booth.id)
        editor.editInspectorDraft { $0.widthM = 3.5 }
        editor.undo()

        dashboard.startSimulation()
        await settle()
        #expect(dashboard.phase == .ready)
    }
}

extension BackFromEditorTests {
    @Test("Through the real screens: editor and back keeps the dashboard's analysis")
    func throughFactory() async throws {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(
            ProjectDraft(name: "P", legend: PreviewLayouts.sampleLegend, layouts: [PreviewLayouts.smallMarket()]),
            for: project.id
        )
        let router = AppRouter()
        let services = AppServices(projectSession: session, presetCatalog: catalog)
        let factory = ProjectScreenFactory(services: services, router: router)

        router.showAnalysis(projectID: project.id)
        let dashboard = factory.makeDashboardViewModel(projectID: project.id)
        dashboard.startSimulation()
        while dashboard.phase == .loading { await Task.yield() }
        #expect(dashboard.phase == .ready)

        dashboard.onEdit(.one)
        #expect(router.destination == .editor(projectID: project.id))
        let editor = factory.makeLayoutEditorViewModel(projectID: project.id)
        editor.refreshDerivedState()
        editor.requestBack()
        #expect(router.destination == .analysis(projectID: project.id))

        let again = factory.makeDashboardViewModel(projectID: project.id)
        #expect(again === dashboard)
        again.startSimulation()
        for _ in 0..<20 { await Task.yield() }
        #expect(again.phase == .ready)
        #expect(!again.isRunning)
    }
}

extension BackFromEditorTests {
    @Test("An unchanged inspector draft applied to any object leaves the object as it was")
    func untouchedDraftIsIdentity() {
        let layout = PreviewLayouts.smallMarket()
        for object in layout.objects {
            let applied = InspectorDraft(object: object).applied(to: object)
            #expect(applied == object, "\(object.kind) changed by an untouched draft")
        }
    }
}

extension BackFromEditorTests {
    @Test("Back from the editor returns to the page it was opened from")
    func backGoesToOrigin() {
        let id = UUID()
        let router = AppRouter()

        router.showSetup(projectID: id)
        router.showEditor(projectID: id)
        router.closeEditor(projectID: id)
        #expect(router.destination == .setup(projectID: id))

        router.showAnalysis(projectID: id)
        router.showEditor(projectID: id)
        router.closeEditor(projectID: id)
        #expect(router.destination == .analysis(projectID: id))
    }
}
