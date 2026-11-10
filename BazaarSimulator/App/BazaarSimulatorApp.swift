import SwiftUI

@main
struct BazaarSimulatorApp: App {
    @State private var services = AppServices(seedsMockProject: LaunchOptions.seedsMockProject)

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            AppCommands()
        }
    }
}
