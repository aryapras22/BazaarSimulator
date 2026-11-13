import SwiftUI

/// The content of the simulation window: one layout of one run, played.
struct SimulationWindowView: View {
    @State private var viewModel: SimulationPlayerViewModel

    init(target: SimulationTarget, session: any ProjectSessionProtocol) {
        _viewModel = State(initialValue: SimulationPlayerViewModel(target: target, session: session))
    }

    var body: some View {
        SimulationPlayerView(viewModel: viewModel)
            .navigationTitle(viewModel.windowTitle)
            .frame(minWidth: 900, minHeight: 640)
            .preferredColorScheme(.dark)
    }
}
