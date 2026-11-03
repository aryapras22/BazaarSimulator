import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct ProjectSessionLayoutTests {
    @Test("updateLayout replaces the matching layout only")
    func updateLayoutReplacesMatchingOnly() {
        let session = ProjectSession()
        let project = session.createProject(named: "Market")
        let layoutA = Layout(name: "Layout A", sizeM: SIMD2<Double>(20, 20))
        let layoutB = Layout(name: "Layout B", sizeM: SIMD2<Double>(30, 30))
        session.setDraft(ProjectDraft(name: "Market", layouts: [layoutA, layoutB]), for: project.id)

        var updatedA = layoutA
        updatedA.name = "Layout A Edited"
        session.updateLayout(updatedA, in: project.id)

        #expect(session.layout(id: layoutA.id, in: project.id)?.name == "Layout A Edited")
        #expect(session.layout(id: layoutB.id, in: project.id)?.name == "Layout B")
    }

    @Test("The active layout is stored per project and defaults to the first layout")
    func activeLayoutStoredPerProject() {
        let session = ProjectSession()
        let firstProject = session.createProject(named: "First")
        let secondProject = session.createProject(named: "Second")

        let layout1 = Layout(name: "L1", sizeM: SIMD2<Double>(20, 20))
        let layout2 = Layout(name: "L2", sizeM: SIMD2<Double>(20, 20))
        let layout3 = Layout(name: "L3", sizeM: SIMD2<Double>(20, 20))

        session.setDraft(ProjectDraft(name: "First", layouts: [layout1, layout2]), for: firstProject.id)
        session.setDraft(ProjectDraft(name: "Second", layouts: [layout3]), for: secondProject.id)

        #expect(session.activeLayoutID(for: firstProject.id) == layout1.id)
        #expect(session.activeLayoutID(for: secondProject.id) == layout3.id)

        session.setActiveLayoutID(layout2.id, for: firstProject.id)

        #expect(session.activeLayoutID(for: firstProject.id) == layout2.id)
        #expect(session.activeLayoutID(for: secondProject.id) == layout3.id)
    }
}
