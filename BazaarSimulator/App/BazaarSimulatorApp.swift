import SwiftUI

@main
struct BazaarSimulatorApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView(services: services)
                .preferredColorScheme(.dark)
        }
    }
}
