import Foundation

enum LaunchOptions {
    /// True when the app is the host of a test run. The tests make their own projects and sessions, so the host
    /// neither seeds the mock projects nor keeps anything on disk, and it must not be shut down while a long
    /// simulation test is running.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Seeds the sample project on launch so new users have a project to learn from. On by default in every build;
    /// the scheme can turn it off with `-seedMockProject NO` (Product > Scheme > Edit Scheme > Run > Arguments).
    static var seedsMockProject: Bool {
        guard !isRunningTests else { return false }
        guard UserDefaults.standard.object(forKey: "seedMockProject") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "seedMockProject")
    }
}
