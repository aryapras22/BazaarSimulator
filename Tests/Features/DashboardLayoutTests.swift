import AppKit
import SwiftUI
import Testing
@testable import BazaarSimulator

@MainActor
@Suite("DashboardLayoutTests")
struct DashboardLayoutTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", mix: ["a": 50, "b": 50])],
        defaultTotalVisitors: 40
    )

    private func makeFastParameters() -> EventParameters {
        EventParameters(
            totalVisitors: 40,
            eventHours: TimeRange(startMinute: 10 * 60, endMinute: 11 * 60),
            bazaarTypeID: "test",
            mix: VisitorMix(equalSplitOf: ["a", "b"])
        )
    }

    private func makeLandscapeLayouts(count: Int) -> [BazaarSimulator.Layout] {
        let names = [
            "More Market I Very Long Floor Plan Name For Testing",
            "More Market II Extra Long Floor Plan Comparison Name"
        ]
        return (0..<count).map { index in
            var layout = TestLayouts.hall(booths: 3 + index, width: 30, depth: 12)
            layout.name = names[index % names.count]
            return layout
        }
    }

    private func makeWindow(width: CGFloat, height: CGFloat, rootView: some View) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: AnyView(rootView))
        window.contentView = hosting
        window.layoutIfNeeded()
        return window
    }

    private func collectViews(in root: NSView, matching predicate: (String) -> Bool) -> [(NSView, CGRect)] {
        var result: [(NSView, CGRect)] = []
        func walk(_ view: NSView) {
            if predicate(String(describing: type(of: view))) {
                result.append((view, view.convert(view.bounds, to: nil)))
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return result
    }

    private func detailFocusRings(in window: NSWindow) -> [CGRect] {
        guard let root = window.contentView else { return [] }
        let containers = collectViews(in: root) {
            $0.contains("_NSSplitViewItemViewWrapper")
        }
        let detailWrapper = containers.map(\.0).first { view in
            collectViews(in: view) { $0.contains("ProjectLibraryView") }.isEmpty
                && !collectViews(in: view) { $0.contains("_FocusRingView") }.isEmpty
        }
        let target = detailWrapper ?? root
        return collectViews(in: target) { $0.contains("_FocusRingView") }.map(\.1)
    }

    private func makeDashboardSplitView(
        sidebarWidth: ClosedRange<CGFloat>,
        layoutCount: Int
    ) -> (DashboardViewModel, AnyView) {
        let session = ProjectSession()
        let project = session.createProject(named: "More Market Long Bazaar Simulation Project")
        let layouts = makeLandscapeLayouts(count: layoutCount)
        session.setDraft(ProjectDraft(name: project.name, layouts: layouts), for: project.id)
        session.setEventParameters(makeFastParameters(), for: project.id)

        let dashboardVM = DashboardViewModel(
            projectID: project.id,
            session: session,
            analysisService: AnalysisService(),
            catalog: catalog
        )
        let libraryVM = ProjectLibraryViewModel(
            session: session,
            destination: { .analysis(projectID: project.id) },
            onOpenProject: { _ in }
        )

        let view = NavigationSplitView {
            ProjectLibraryView(viewModel: libraryVM)
                .navigationSplitViewColumnWidth(
                    min: sidebarWidth.lowerBound,
                    ideal: sidebarWidth.lowerBound,
                    max: sidebarWidth.upperBound
                )
        } detail: {
            DashboardView(viewModel: dashboardVM) { _ in EmptyView() }
        }
        .frame(minWidth: 1280, minHeight: 800)
        .appBackground()
        .preferredColorScheme(.dark)

        return (dashboardVM, AnyView(view))
    }

    private func waitUntilReady(_ viewModel: DashboardViewModel, in window: NSWindow) async {
        while viewModel.phase == .loading {
            try? await Task.sleep(for: .milliseconds(25))
        }
        try? await Task.sleep(for: .milliseconds(150))
        window.layoutIfNeeded()
    }

    private func hasGlassBackgroundLayer(in layer: CALayer?) -> Bool {
        guard let layer else { return false }
        if let filters = layer.filters,
           filters.contains(where: { String(describing: $0).localizedCaseInsensitiveContains("glassBackground") }) {
            return true
        }
        return (layer.sublayers ?? []).contains { hasGlassBackgroundLayer(in: $0) }
    }

    @Test("ParametersView uses an Apple Liquid Glass container")
    func parametersViewUsesLiquidGlassContainer() async {
        let session = ProjectSession()
        let project = session.createProject(named: "Liquid Glass Test")
        let viewModel = ParametersViewModel(
            projectID: project.id,
            session: session,
            catalog: PresetCatalog.bundled(),
            onClose: {}
        )
        let window = makeWindow(width: 960, height: 700, rootView: ParametersView(viewModel: viewModel))
        window.displayIfNeeded()
        try? await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()

        #expect(hasGlassBackgroundLayer(in: window.contentView?.layer))
    }

    @Test("Two-layout Analysis page stays clear of 240pt sidebar and reacts to window resize")
    func dashboardTwoLayoutsStaysClearOfSidebarAndReactsToResize() async {
        let (viewModel, splitView) = makeDashboardSplitView(sidebarWidth: 240...300, layoutCount: 2)
        let window = makeWindow(width: 1280, height: 800, rootView: splitView)
        await waitUntilReady(viewModel, in: window)

        let frames1280 = detailFocusRings(in: window)
        #expect(frames1280.count >= 9)
        for frame in frames1280 {
            #expect(frame.minX >= 240, "Control overlapped sidebar at \(frame)")
            #expect(frame.maxX <= 1280, "Control overflowed window width at \(frame)")
        }

        let maxX1280 = frames1280.map(\.maxX).max() ?? 0
        window.setContentSize(NSSize(width: 1520, height: 900))
        try? await Task.sleep(for: .milliseconds(150))
        window.layoutIfNeeded()

        let frames1520 = detailFocusRings(in: window)
        let maxX1520 = frames1520.map(\.maxX).max() ?? 0
        #expect(maxX1520 > 1280 && maxX1520 > maxX1280 + 150)
        for frame in frames1520 {
            #expect(frame.minX >= 240, "Control overlapped sidebar after resize at \(frame)")
            #expect(frame.maxX <= 1520, "Control overflowed resized window at \(frame)")
        }

        window.setContentSize(NSSize(width: 1280, height: 800))
        try? await Task.sleep(for: .milliseconds(150))
        window.layoutIfNeeded()
        for frame in detailFocusRings(in: window) {
            #expect(frame.minX >= 240, "Control overlapped sidebar after shrinking at \(frame)")
            #expect(frame.maxX <= 1280, "Control overflowed shrunk window at \(frame)")
        }
    }

    @Test("Two-layout Analysis page still fits cleanly when sidebar is widened to 300pt")
    func dashboardWithMax300SidebarFits() async {
        let (viewModel, splitView) = makeDashboardSplitView(sidebarWidth: 300...300, layoutCount: 2)
        let window = makeWindow(width: 1280, height: 800, rootView: splitView)
        await waitUntilReady(viewModel, in: window)

        let frames = detailFocusRings(in: window)
        #expect(frames.count >= 9)
        for frame in frames {
            #expect(frame.minX >= 300, "Control overlapped 300pt sidebar at \(frame)")
            #expect(frame.maxX <= 1280, "Control overflowed 1280pt window at \(frame)")
        }
    }

    @Test("Single-layout Analysis page with long names and landscape plan fits clear of sidebar")
    func dashboardSingleLayoutFits() async {
        let (viewModel, splitView) = makeDashboardSplitView(sidebarWidth: 240...300, layoutCount: 1)
        let window = makeWindow(width: 1280, height: 800, rootView: splitView)
        await waitUntilReady(viewModel, in: window)

        let frames = detailFocusRings(in: window)
        #expect(frames.count >= 6)
        for frame in frames {
            #expect(frame.minX >= 240, "Single-layout control overlapped sidebar at \(frame)")
            #expect(frame.maxX <= 1280, "Single-layout control overflowed window at \(frame)")
        }
    }

    @Test("Saved Analysis page keeps the Parameters button at the top right")
    func savedAnalysisHeaderKeepsParametersButton() async throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Saved Header Test")
        let layouts = makeLandscapeLayouts(count: 2)
        session.setDraft(ProjectDraft(name: project.name, layouts: layouts), for: project.id)
        session.setEventParameters(makeFastParameters(), for: project.id)

        let runner = DashboardViewModel(
            projectID: project.id, session: session, analysisService: AnalysisService(), catalog: catalog
        )
        await runner.runSimulation()
        let saved = try #require(session.savedAnalyses(for: project.id).first)

        let savedVM = DashboardViewModel(
            projectID: project.id, source: .saved(saved.id),
            session: session, analysisService: AnalysisService(), catalog: catalog
        )
        let libraryVM = ProjectLibraryViewModel(
            session: session,
            destination: { .savedAnalysis(projectID: project.id, analysisID: saved.id) },
            onOpenProject: { _ in }
        )
        let splitView = NavigationSplitView {
            ProjectLibraryView(viewModel: libraryVM)
                .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 300)
        } detail: {
            DashboardView(viewModel: savedVM) { _ in EmptyView() }
        }
        .frame(minWidth: 1280, minHeight: 800)

        let window = makeWindow(width: 1280, height: 800, rootView: splitView)
        try? await Task.sleep(for: .milliseconds(150))
        window.layoutIfNeeded()

        let frames = detailFocusRings(in: window)
        let hasTopRightParametersButton = frames.contains { $0.minX > 1000 && $0.maxY > 760 }
        #expect(hasTopRightParametersButton)
    }

    @Test("Visitor types use the configured brand colors in order")
    func visitorTypeColorsMatchExpectedHexValues() {
        let items = VisitorSliderItem.items(for: PresetCatalog.bundled().visitorTypes)
        let expected: [(String, UInt)] = [
            ("Socializer", 0x0A80E1),
            ("Family", 0x13B6C7),
            ("Explorer", 0xDA8133),
            ("Shopper", 0xBD34D4)
        ]

        #expect(items.map(\.name) == expected.map(\.0))
        for (item, (_, hex)) in zip(items, expected) {
            #expect(item.color == Color(hex: hex))
        }
    }
}
