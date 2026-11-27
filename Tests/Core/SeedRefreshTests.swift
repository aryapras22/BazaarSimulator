import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("SeedRefreshTests")
@MainActor
struct SeedRefreshTests {
    @Test("Untouched seeded project refreshes when its seed fingerprint changes")
    func untouchedSeededProjectRefreshesWhenSeedChanges() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }
        let firstSession = openAndSeed(at: store.rootForTesting)
        let project = try #require(firstSession.project(named: "Lantern Night Market"))
        let seededLayouts = try #require(firstSession.draft(for: project.id)?.layouts)
        let saved = try #require(firstSession.recordAnalysis(
            layouts: seededLayouts,
            analyses: seededLayouts.map(sampleAnalysis(for:)),
            parameters: TestLayouts.parameters,
            peakMinute: 660,
            in: project.id
        ))
        let initialJSON = try readDraftJSON(in: store, for: project.id)
        let currentFingerprint = try #require(seedFingerprint(in: initialJSON))
        #expect(!currentFingerprint.isEmpty)

        var staleJSON = try renamingFirstLayout(in: initialJSON, to: "Stale Seed Plan")
        staleJSON["seedFingerprint"] = "stale-seed-fingerprint"
        try writeDraftJSON(staleJSON, in: store, for: project.id)

        let reopened = openAndSeed(at: store.rootForTesting)

        let refreshedProject = try #require(reopened.project(named: "Lantern Night Market"))
        #expect(refreshedProject.id == project.id)
        let refreshedDraft = try #require(reopened.draft(for: project.id))
        #expect(refreshedDraft.layouts.first?.name == "Seoul Food Week")
        let refreshedJSON = try readDraftJSON(in: store, for: project.id)
        #expect(seedFingerprint(in: refreshedJSON) == currentFingerprint)
        let restoredAnalyses = reopened.savedAnalyses(for: project.id)
        #expect(restoredAnalyses.count == 1)
        let restored = try #require(restoredAnalyses.first)
        #expect(restored.id == saved.id)
        #expect(restored.name == saved.name)
        #expect(restored.parameters == saved.parameters)
        #expect(restored.layouts == saved.layouts)
        #expect(restored.analyses == saved.analyses)
        #expect(restored.peakMinute == saved.peakMinute)
    }

    @Test("Relaunching with the same seed keeps layout IDs and produces a stable fingerprint")
    func sameSeedRelaunchKeepsDraftAndStableFingerprint() throws {
        let firstStore = temporaryStore()
        let secondStore = temporaryStore()
        defer {
            try? FileManager.default.removeItem(at: firstStore.rootForTesting)
            try? FileManager.default.removeItem(at: secondStore.rootForTesting)
        }
        let firstSession = openAndSeed(at: firstStore.rootForTesting)
        let secondSession = openAndSeed(at: secondStore.rootForTesting)
        let firstLantern = try #require(firstSession.project(named: "Lantern Night Market"))
        let secondLantern = try #require(secondSession.project(named: "Lantern Night Market"))
        let riverside = try #require(firstSession.project(named: "Riverside Weekend Bazaar"))
        let initialLayoutIDs = try #require(firstSession.draft(for: firstLantern.id)?.layouts.map(\.id))
        #expect(!initialLayoutIDs.isEmpty)
        let firstFingerprint = try #require(
            seedFingerprint(in: try readDraftJSON(in: firstStore, for: firstLantern.id))
        )
        let secondFingerprint = try #require(
            seedFingerprint(in: try readDraftJSON(in: secondStore, for: secondLantern.id))
        )
        let riversideFingerprint = try #require(
            seedFingerprint(in: try readDraftJSON(in: firstStore, for: riverside.id))
        )

        let reopened = openAndSeed(at: firstStore.rootForTesting)

        #expect(!firstFingerprint.isEmpty)
        #expect(firstFingerprint == secondFingerprint)
        #expect(firstFingerprint != riversideFingerprint)
        let reopenedLayoutIDs = try #require(reopened.draft(for: firstLantern.id)?.layouts.map(\.id))
        let reopenedFingerprint = seedFingerprint(
            in: try readDraftJSON(in: firstStore, for: firstLantern.id)
        )
        #expect(reopenedLayoutIDs == initialLayoutIDs)
        #expect(reopenedFingerprint == firstFingerprint)
    }

    @Test("Editing a layout clears the seed fingerprint and preserves the edit on relaunch")
    func updateLayoutClearsSeedFingerprintAndPreservesEdit() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }
        let session = openAndSeed(at: store.rootForTesting)
        let project = try #require(session.project(named: "Lantern Night Market"))
        let initialJSON = try readDraftJSON(in: store, for: project.id)
        let initialFingerprint = try #require(seedFingerprint(in: initialJSON))
        #expect(!initialFingerprint.isEmpty)

        var edited = try #require(session.draft(for: project.id)?.layouts.first)
        edited.name = "Custom Lantern Plan"
        session.updateLayout(edited, in: project.id)
        let editedJSON = try readDraftJSON(in: store, for: project.id)
        #expect(isAbsentOrNull(editedJSON["seedFingerprint"]))

        let reopened = openAndSeed(at: store.rootForTesting)

        let restored = try #require(reopened.draft(for: project.id))
        #expect(restored.layouts.first?.name == "Custom Lantern Plan")
        let reopenedJSON = try readDraftJSON(in: store, for: project.id)
        #expect(isAbsentOrNull(reopenedJSON["seedFingerprint"]))
    }

    @Test("Replacing a draft via setDraft clears the seed fingerprint and preserves changes on relaunch")
    func setDraftClearsSeedFingerprintAndPreservesChanges() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }
        let session = openAndSeed(at: store.rootForTesting)
        let project = try #require(session.project(named: "Lantern Night Market"))
        let initialJSON = try readDraftJSON(in: store, for: project.id)
        let initialFingerprint = try #require(seedFingerprint(in: initialJSON))
        #expect(!initialFingerprint.isEmpty)

        var modifiedDraft = try #require(session.draft(for: project.id))
        var renamedFirst = try #require(modifiedDraft.layouts.first)
        renamedFirst.name = "Replaced Draft Plan"
        modifiedDraft.layouts[0] = renamedFirst
        session.setDraft(modifiedDraft, for: project.id)
        let savedJSON = try readDraftJSON(in: store, for: project.id)
        #expect(isAbsentOrNull(savedJSON["seedFingerprint"]))

        let reopened = openAndSeed(at: store.rootForTesting)

        let restored = try #require(reopened.draft(for: project.id))
        #expect(restored.layouts.first?.name == "Replaced Draft Plan")
        let reopenedJSON = try readDraftJSON(in: store, for: project.id)
        #expect(isAbsentOrNull(reopenedJSON["seedFingerprint"]))
    }

    @Test("Legacy draft without a seed fingerprint decodes cleanly and is preserved on relaunch")
    func legacyDraftWithoutSeedFingerprintIsPreservedOnRelaunch() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }
        let session = openAndSeed(at: store.rootForTesting)
        let project = try #require(session.project(named: "Lantern Night Market"))
        let initialJSON = try readDraftJSON(in: store, for: project.id)
        let initialFingerprint = try #require(seedFingerprint(in: initialJSON))
        #expect(!initialFingerprint.isEmpty)

        var legacyJSON = try renamingFirstLayout(in: initialJSON, to: "Legacy User Layout")
        legacyJSON.removeValue(forKey: "seedFingerprint")
        try writeDraftJSON(legacyJSON, in: store, for: project.id)

        let reopened = openAndSeed(at: store.rootForTesting)

        let restoredProject = try #require(reopened.project(named: "Lantern Night Market"))
        #expect(restoredProject.id == project.id)
        let restoredDraft = try #require(reopened.draft(for: project.id))
        #expect(restoredDraft.layouts.first?.name == "Legacy User Layout")
        let persistedJSON = try readDraftJSON(in: store, for: project.id)
        #expect(persistedJSON["seedFingerprint"] == nil)
    }

    private func temporaryStore() -> FileSavedAnalysisStore {
        FileSavedAnalysisStore(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent("seed-refresh-tests-\(UUID().uuidString)")
        )
    }

    private func openAndSeed(at root: URL) -> ProjectSession {
        let session = ProjectSession(store: FileSavedAnalysisStore(root: root))
        _ = AppServices(projectSession: session, seedsMockProject: true)
        return session
    }

    private func draftURL(in store: FileSavedAnalysisStore, for projectID: UUID) -> URL {
        store.rootForTesting
            .appendingPathComponent("Drafts")
            .appendingPathComponent("\(projectID.uuidString).json")
    }

    private func readDraftJSON(
        in store: FileSavedAnalysisStore,
        for projectID: UUID
    ) throws -> [String: Any] {
        let data = try Data(contentsOf: draftURL(in: store, for: projectID))
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func writeDraftJSON(
        _ json: [String: Any],
        in store: FileSavedAnalysisStore,
        for projectID: UUID
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: draftURL(in: store, for: projectID), options: .atomic)
    }

    private func seedFingerprint(in json: [String: Any]) -> String? {
        json["seedFingerprint"] as? String
    }

    private func isAbsentOrNull(_ value: Any?) -> Bool {
        value == nil || value is NSNull
    }

    private func renamingFirstLayout(
        in json: [String: Any],
        to name: String
    ) throws -> [String: Any] {
        var updated = json
        var layouts = try #require(updated["layouts"] as? [[String: Any]])
        var first = try #require(layouts.first)
        first["name"] = name
        layouts[0] = first
        updated["layouts"] = layouts
        return updated
    }

    private func sampleAnalysis(for layout: Layout) -> LayoutAnalysis {
        let spot = SpotMeasurement(
            number: 1,
            name: "Near B1",
            position: SIMD2(4, 5),
            densitySamples: [0.2, 0.5],
            peopleSamples: [2, 5]
        )
        var measured = LayoutAnalysis(
            layoutID: layout.id,
            eventStartMinute: 600,
            sampleIntervalSeconds: 60,
            spots: [spot],
            flowPerMinute: [2, 3],
            simulatedPeople: 40,
            totalPeople: 40
        )
        measured.plan = PlanFrame(origin: .zero, size: layout.sizeM)
        return measured
    }
}
