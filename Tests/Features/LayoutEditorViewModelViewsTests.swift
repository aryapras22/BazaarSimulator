import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelViewsTests {

    private static func makeViewModel() -> LayoutEditorViewModel {
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        return viewModel
    }

    @Test("The attractiveness scale clamps values outside 1 to 5")
    func attractivenessScaleClamps() {
        #expect(AttractivenessScale.fraction(of: -3) == 0)
        #expect(AttractivenessScale.fraction(of: 3) == 0.5)
        #expect(AttractivenessScale.fraction(of: 40) == 1)
    }

    @Test("A resize refits the canvas until the user zooms or pans")
    func resizeRefitsOnlyWhileUntouched() {
        let viewModel = Self.makeViewModel()
        let layoutSize = viewModel.layout.sizeM
        viewModel.fitToView(in: SIMD2<Double>(960, 640))

        viewModel.refitIfUntouched(in: SIMD2<Double>(1400, 900))
        #expect(viewModel.transform == CanvasTransform.fitting(layoutSize: layoutSize, in: SIMD2<Double>(1400, 900)))

        viewModel.transform = viewModel.transform.panned(by: SIMD2<Double>(20, 0))
        let panned = viewModel.transform
        viewModel.refitIfUntouched(in: SIMD2<Double>(600, 400))
        #expect(viewModel.transform == panned)
    }
}
