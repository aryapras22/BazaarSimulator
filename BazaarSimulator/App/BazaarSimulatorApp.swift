import SwiftUI

@main
struct BazaarSimulatorApp: App {
    @State private var services = AppServices(seedsMockProject: LaunchOptions.seedsMockProject)

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .preferredColorScheme(.dark)
        }
        .commands {
            AppCommands()
        }
    }
}
