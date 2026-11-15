import SwiftUI

@main
struct BazaarSimulatorApp: App {
    @State private var services = AppServices(
        projectSession: ProjectSession(store: LaunchOptions.isRunningTests ? nil : FileSavedAnalysisStore()),
        seedsMockProject: LaunchOptions.seedsMockProject
    )

    init() {
        if LaunchOptions.isRunningTests {
            // macOS can quietly quit an app that sits idle with no window. A test run is idle for minutes while a
            // simulation finishes, and the quit ends the whole run.
            ProcessInfo.processInfo.disableAutomaticTermination("Running tests")
            ProcessInfo.processInfo.disableSuddenTermination()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1280, height: 800)
        // Standard window controls and sidebar button, with no title text over the content.
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppCommands()
        }

        // The simulator opens in its own window, titled with the bazaar and the layout.
        WindowGroup("Simulation", id: SimulationWindowContent.windowID, for: SimulationRequest.self) { $request in
            if let request {
                SimulationWindowContent(request: request, services: services)
            }
        }
        .defaultSize(width: 1546, height: 1008)
        .windowResizability(.contentMinSize)
        // A simulator window belongs to one run of the app, so it is not brought back on launch.
        .restorationBehavior(.disabled)
    }
}
