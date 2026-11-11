import Foundation
import Testing
@testable import BazaarSimulator

@Suite("SimulationViewModel Tests")
@MainActor
struct SimulationViewModelTests {

    @Test("ViewModel controls play, pause, fastForward, and reset")
    func playbackControls() {
        let layout = PreviewLayouts.smallMarket()
        let viewModel = SimulationViewModel(layout: layout)

        #expect(!viewModel.isRunning)
        #expect(viewModel.clockString == "00:00:00")

        viewModel.togglePlay()
        #expect(viewModel.isRunning)

        viewModel.tick(realSeconds: 0.5)
        #expect(viewModel.metrics.elapsedSeconds > 0)

        viewModel.fastForward(minutes: 2)
        #expect(viewModel.metrics.elapsedSeconds >= 120)
        #expect(viewModel.metrics.arrivals > 0)

        viewModel.reset()
        #expect(!viewModel.isRunning)
        #expect(viewModel.visitors.isEmpty)
        #expect(viewModel.metrics.elapsedSeconds == 0)
    }

    @Test("ViewModel loads and scrubs saved simulation footage")
    func savedFootagePlayback() async {
        let layout = PreviewLayouts.smallMarket()
        let engine = SimulationEngine(layout: layout)
        let savedResult = await engine.runWithRecordedFootage(durationMinutes: 2, frameIntervalSeconds: 10.0)

        let viewModel = SimulationViewModel(layout: layout, savedResult: savedResult)

        #expect(viewModel.hasRecordedFootage)
        #expect(viewModel.totalFrames == savedResult.frames.count)

        viewModel.seekToFrame(savedResult.frames.count - 1)
        #expect(viewModel.currentFrameIndex == savedResult.frames.count - 1)
        #expect(viewModel.metrics.elapsedSeconds == 120.0)
    }

    @Test("Background simulation runs report progress, and a newer run replaces an older one")
    func backgroundRunsPublishResults() async {
        let session = ProjectSession()
        let project = session.createProject(named: "Run")
        let layout = PreviewLayouts.smallMarket()
        session.setDraft(ProjectDraft(name: "Run", layouts: [layout]), for: project.id)
        var parameters = EventParameters(totalVisitors: 20, startMinutes: 600, endMinutes: 615)
        session.setParameters(parameters, for: project.id)

        session.runSimulations(for: project.id)
        #expect(session.isSimulating(project.id))
        parameters.totalVisitors = 5
        session.setParameters(parameters, for: project.id)
        session.runSimulations(for: project.id)

        while session.isSimulating(project.id) { await Task.yield() }

        #expect(session.simulationResult(for: layout.id, in: project.id)?.metrics.arrivals == 5)
    }
}
