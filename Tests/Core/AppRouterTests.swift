import Testing
@testable import BazaarSimulator

@Suite("AppRouterTests")
struct AppRouterTests {
    @Test("No project selected shows the empty workspace")
    func noProjectSelectedShowsEmpty() {
        let router = AppRouter()
        #expect(router.destination == .empty)
    }

    @Test("A new project shows setup")
    func newProjectShowsSetup() {
        let router = AppRouter()
        router.showSetup()
        #expect(router.destination == .setup)
    }

    @Test("Continue shows the review placeholder")
    func continueShowsReviewPlaceholder() {
        let router = AppRouter(destination: .setup)
        router.showReviewPlaceholder()
        #expect(router.destination == .reviewPlaceholder)
    }
}
