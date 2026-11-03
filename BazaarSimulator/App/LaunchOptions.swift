import Foundation

enum LaunchOptions {
    /// Seeds the mock project on launch. Debug builds only, and only when the scheme passes
    /// `-seedMockProject YES` (Product > Scheme > Edit Scheme > Run > Arguments).
    static var seedsMockProject: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "seedMockProject")
        #else
        return false
        #endif
    }
}
