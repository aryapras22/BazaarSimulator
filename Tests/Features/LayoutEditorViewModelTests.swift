import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelTests {
    struct TestContext {
        let viewModel: LayoutEditorViewModel
        let session: ProjectSession
        let layout: Layout
    }

    static func makeContext() -> TestContext {
        let session = ProjectSession()
        let project = session.createProject(named: "Test Market")
        let layout = PreviewLayouts.smallMarket()
        let draft = ProjectDraft(
            name: "Test Market",
            legend: PreviewLayouts.sampleLegend,
            layouts: [layout]
        )
        session.setDraft(draft, for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        return TestContext(viewModel: viewModel, session: session, layout: layout)
    }

    @Test("Selecting a booth fills the inspector draft")
    func selectingBoothFillsDraft() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)

        #expect(context.viewModel.selectionID == booth.id)
        #expect(context.viewModel.inspectorDraft?.objectID == booth.id)
        #expect(context.viewModel.inspectorDraft?.widthM == booth.placement.sizeM.x)
    }

    @Test("Switching tabs clears the selection")
    func switchingTabsClearsSelection() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)
        #expect(context.viewModel.selectionID == booth.id)

        context.viewModel.selectTab(.flow)

        #expect(context.viewModel.tab == .flow)
        #expect(context.viewModel.selectionID == nil)
        #expect(context.viewModel.inspectorDraft == nil)
    }

    @Test("Flow tab ignores a booth click")
    func flowTabIgnoresBoothClick() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectTab(.flow)

        context.viewModel.selectObject(booth.id)

        #expect(context.viewModel.selectionID == nil)
    }
}
