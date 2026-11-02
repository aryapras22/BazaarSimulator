import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutValidatorTests {
    private let defaultHall: [SIMD2<Double>] = [
        SIMD2<Double>(0, 0),
        SIMD2<Double>(20, 0),
        SIMD2<Double>(20, 20),
        SIMD2<Double>(0, 20)
    ]

    @Test("Overlapping booths give one warning naming both")
    func overlappingBoothsWarning() {
        let boothA = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            openSides: [.top]
        )
        let boothB = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(6, 5), sizeM: SIMD2<Double>(2, 2)),
            openSides: [.bottom]
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [boothA, boothB]
        )

        let overlapIssues = LayoutValidator.issues(in: layout).filter { $0.kind == .overlappingObjects }

        #expect(overlapIssues.count == 1)
        #expect(overlapIssues.first?.severity == .warning)
        #expect(overlapIssues.first?.message.contains("B1") == true)
        #expect(overlapIssues.first?.message.contains("B2") == true)
    }

    @Test("A booth outside both polygons gives a warning")
    func boothOutsidePolygonsWarning() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(25, 25), sizeM: SIMD2<Double>(2, 2)),
            openSides: .all
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(30, 30),
            hall: defaultHall,
            objects: [booth]
        )

        let issues = LayoutValidator.issues(in: layout)

        #expect(issues.contains { $0.kind == .outsideFloor && $0.severity == .warning })
    }

    @Test("An open side against another booth gives a warning")
    func openSideAgainstBoothWarning() {
        let boothA = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 9), sizeM: SIMD2<Double>(2, 2)),
            openSides: [.bottom]
        )
        let boothB = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(10, 11), sizeM: SIMD2<Double>(2, 2)),
            openSides: [.bottom]
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [boothA, boothB]
        )

        let issues = LayoutValidator.issues(in: layout)

        #expect(issues.contains { $0.kind == .blockedOpenSide(side: .bottom) && $0.objectIDs == [boothA.id] })
    }

    @Test("A booth with no open sides gives a warning")
    func boothWithNoOpenSidesWarning() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2)),
            openSides: []
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth]
        )

        let issues = LayoutValidator.issues(in: layout)

        #expect(issues.contains { $0.kind == .noOpenSides && $0.message == LayoutIssueText.noOpenSides })
    }

    @Test("Hall doors with no entrance give a warning")
    func hallDoorsWithNoEntranceWarning() {
        let door = LayoutObject(
            kind: .door,
            label: "Door A",
            placement: Placement(center: SIMD2<Double>(10, 20), sizeM: SIMD2<Double>(2, 0.4)),
            doorFlow: DoorFlow(direction: .exit, connection: .hallToLobby)
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [door]
        )

        let issues = LayoutValidator.issues(in: layout)

        #expect(issues.contains { $0.kind == .missingHallDoorEntry && $0.severity == .warning })
    }

    @Test("A booth below the minimum size gives an error")
    func boothBelowMinimumSizeError() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(0.3, 2.0)),
            openSides: .all
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth]
        )

        let issues = LayoutValidator.issues(in: layout)

        #expect(issues.contains { $0.kind == .belowMinimumSize && $0.severity == .error })
    }
}
