import SwiftUI

/// The content of a simulator window: one layout of one project, played over its floor plan.
struct SimulationWindowContent: View {
    static let windowID = "simulation"

    @State private var viewModel: SimulationPlayerViewModel

    init(request: SimulationRequest, services: AppServices) {
        _viewModel = State(initialValue: SimulationPlayerViewModel(
            projectID: request.projectID,
            layoutID: request.layout,
            analysisID: request.analysisID,
            session: services.projectSession,
            analysisService: services.analysisService,
            catalog: services.presetCatalog
        ))
    }

    var body: some View {
        SimulationPlayerView(viewModel: viewModel)
            .navigationTitle(viewModel.windowTitle)
            .frame(minWidth: 1100, minHeight: 720)
            .preferredColorScheme(.dark)
            .windowToolbarFullScreenVisibility(.onHover)
    }
}
