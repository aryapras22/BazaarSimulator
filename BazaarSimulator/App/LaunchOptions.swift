import Foundation

enum LaunchOptions {
    /// Seeds the mock project on launch. Debug builds only. On by default; the scheme can turn it off with
    /// `-seedMockProject NO` (Product > Scheme > Edit Scheme > Run > Arguments).
    static var seedsMockProject: Bool {
        #if DEBUG
        guard UserDefaults.standard.object(forKey: "seedMockProject") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "seedMockProject")
        #else
        return false
        #endif
    }
}
