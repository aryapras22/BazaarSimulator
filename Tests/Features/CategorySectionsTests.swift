import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct CategorySectionsTests {
    private func booth() -> LayoutObject {
        LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            openSides: [.bottom]
        )
    }

    @Test("Entertainment is added as a booth, so it has no add button of its own")
    func noEntertainmentButton() {
        #expect(EditorAddTool.tools(for: .booths) == [.booth, .table])
        #expect(!ObjectCatalog.libraryItems.contains { $0.kind == .entertainment })
    }

    @Test("Others and Disabled sit in their own Others section")
    func othersSection() {
        #expect(EntertainmentType.allCases.filter(\.isInOthersSection) == [.other, .disabled])
    }

    @Test("A booth turned into a stage takes the stage's height, and back again the booth's")
    func heightFollowsType() throws {
        let original = booth()
        var draft = InspectorDraft(object: original)
        draft.choose(.entertainment(.stage))
        let stage = draft.applied(to: original)
        let stageHeight = try #require(ObjectCatalog.item(EntertainmentType.stage.catalogID)?.heightM)
        #expect(stage.heightM == stageHeight)

        var back = InspectorDraft(object: stage)
        back.choose(.booth(nil))
        #expect(back.applied(to: stage).heightM == InspectorDraft.defaultHeight(for: original))
    }
}
