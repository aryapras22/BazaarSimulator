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

        #expect(issues.contains {
            $0.kind == .noOpenSides
                && $0.objectIDs == [booth.id]
                && $0.message == "Visitors cannot reach B1"
        })
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

    @Test("A block just outside the hall edge is not flagged")
    func blockOutsideHallEdgeNotFlagged() {
        let pillar = LayoutObject(
            kind: .block,
            label: "P1",
            placement: Placement(center: SIMD2<Double>(-0.1, 10), sizeM: SIMD2<Double>(0.5, 0.5))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [pillar]
        )

        let issues = LayoutValidator.issues(in: layout)

        #expect(!issues.contains { $0.kind == .outsideFloor })
    }

    @Test("A booth half outside the hall is flagged")
    func boothHalfOutsideHallFlagged() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(0, 10), sizeM: SIMD2<Double>(2, 2)),
            openSides: .right
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth]
        )

        let issues = LayoutValidator.issues(in: layout)

        #expect(issues.contains { $0.kind == .outsideFloor && $0.objectIDs == [booth.id] })
    }

    @Test("A booth overlapping a blocked area warns")
    func boothInBlockedAreaWarns() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            openSides: .all
        )
        let blocked = LayoutObject(
            kind: .closedArea,
            label: "Storage",
            placement: Placement(center: SIMD2<Double>(5.5, 5), sizeM: SIMD2<Double>(3, 3))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth, blocked]
        )

        let issues = LayoutValidator.issues(in: layout)
        #expect(issues.contains {
            $0.kind == .overlappingObjects
                && $0.objectIDs == [booth.id]
                && $0.message.contains("B1")
                && $0.message.contains("Storage")
        })
        #expect(!issues.contains { $0.objectIDs.contains(blocked.id) })
    }

    @Test("Touching by 0.05m is under overlap tolerance and clean")
    func touchUnderToleranceIsClean() {
        let table = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            openSides: .left
        )
        // Booth right edge is 6.0. Blocked area left edge is 6.0 - 0.05 = 5.95 -> center 7.45, width 3.0
        let blocked = LayoutObject(
            kind: .closedArea,
            label: "Blocked",
            placement: Placement(center: SIMD2<Double>(7.45, 5), sizeM: SIMD2<Double>(3, 3))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [table, blocked]
        )

        let issues = LayoutValidator.issues(in: layout)
        #expect(!issues.contains { $0.kind == .overlappingObjects })
    }
}

extension LayoutValidatorTests {
    private func makeLayout(size: Double = 30, objects: [LayoutObject]) -> Layout {
        Layout(name: "Test", sizeM: SIMD2<Double>(size, size), hall: defaultHall, objects: objects)
    }

    private func makeObject(
        _ kind: LayoutObjectKind,
        _ label: String,
        center: SIMD2<Double>,
        size: SIMD2<Double>,
        openSides: OpenSides = []
    ) -> LayoutObject {
        LayoutObject(kind: kind, label: label, placement: Placement(center: center, sizeM: size), openSides: openSides)
    }

    @Test("Undersized structure objects produce no validation issues")
    func undersizedStructureObjectsProduceNoIssues() {
        let wall = makeObject(.wall, "W1", center: SIMD2(5, 5), size: SIMD2(0.05, 0.05))
        let block = makeObject(.block, "P1", center: SIMD2(10, 5), size: SIMD2(0.05, 0.05))
        let closedArea = makeObject(.closedArea, "C1", center: SIMD2(15, 5), size: SIMD2(0.2, 0.2))
        let issues = LayoutValidator.issues(in: makeLayout(objects: [wall, block, closedArea]))
        let structureIDs: Set<UUID> = [wall.id, block.id, closedArea.id]

        #expect(issues.allSatisfy { Set($0.objectIDs).isDisjoint(with: structureIDs) })
        #expect(!issues.contains { $0.kind == .belowMinimumSize })
    }

    @Test("Out-of-bounds structure objects produce no validation issues")
    func outOfBoundsStructureObjectsProduceNoIssues() {
        let wall = makeObject(.wall, "W1", center: SIMD2(25, 25), size: SIMD2(2, 0.3))
        let block = makeObject(.block, "P1", center: SIMD2(27, 25), size: SIMD2(1, 1))
        let closedArea = makeObject(.closedArea, "C1", center: SIMD2(30, 25), size: SIMD2(2, 2))
        let issues = LayoutValidator.issues(in: makeLayout(size: 35, objects: [wall, block, closedArea]))
        let structureIDs: Set<UUID> = [wall.id, block.id, closedArea.id]

        #expect(issues.allSatisfy { Set($0.objectIDs).isDisjoint(with: structureIDs) })
        #expect(!issues.contains { $0.kind == .outsideFloor })
    }

    @Test("Booth overlapping structure objects never attaches structure IDs to issues")
    func boothOverlappingStructureObjectsExcludesStructureIDs() {
        let booth = makeObject(.booth, "B1", center: SIMD2(5, 5), size: SIMD2(2, 2), openSides: .all)
        let wall = makeObject(.wall, "North Wall", center: SIMD2(5, 5), size: SIMD2(3, 0.3))
        let block = makeObject(.block, "Column", center: SIMD2(5.2, 5), size: SIMD2(1, 1))
        let closedArea = makeObject(.closedArea, "Storage", center: SIMD2(5.5, 5), size: SIMD2(3, 3))
        let issues = LayoutValidator.issues(in: makeLayout(objects: [booth, wall, block, closedArea]))
        let structureIDs: Set<UUID> = [wall.id, block.id, closedArea.id]
        let overlapIssues = issues.filter { $0.kind == .overlappingObjects }

        #expect(overlapIssues.count == 3)
        #expect(overlapIssues.allSatisfy { $0.objectIDs == [booth.id] })
        #expect(issues.allSatisfy { Set($0.objectIDs).isDisjoint(with: structureIDs) })
    }

    @Test("noOpenSides message names the booth label and never says this booth")
    func noOpenSidesMessageNamesObjectLabel() throws {
        let booth = makeObject(.booth, "N1", center: SIMD2(5, 5), size: SIMD2(2, 2))
        let issues = LayoutValidator.issues(in: makeLayout(objects: [booth]))
        let issue = try #require(issues.first { $0.kind == .noOpenSides })

        #expect(issue.objectIDs == [booth.id])
        #expect(issue.message == "Visitors cannot reach N1")
        #expect(!issue.message.contains("this booth"))
    }

    @Test("blockedOpenSide message names the booth label and never says this booth")
    func blockedOpenSideMessageNamesObjectLabel() throws {
        let boothA = makeObject(.booth, "N2", center: SIMD2(10, 9), size: SIMD2(2, 2), openSides: [.bottom])
        let boothB = makeObject(.booth, "N3", center: SIMD2(10, 11), size: SIMD2(2, 2), openSides: [.bottom])
        let issues = LayoutValidator.issues(in: makeLayout(objects: [boothA, boothB]))
        let issue = try #require(issues.first { $0.kind == .blockedOpenSide(side: .bottom) })

        #expect(issue.objectIDs == [boothA.id])
        #expect(issue.message.contains("N2"))
        #expect(!issue.message.contains("this booth"))
    }

    @Test("belowMinimumSize message names the object label and never says this booth")
    func belowMinimumSizeMessageNamesObjectLabel() throws {
        let booth = makeObject(.booth, "N4", center: SIMD2(10, 10), size: SIMD2(0.3, 2.0), openSides: .all)
        let issues = LayoutValidator.issues(in: makeLayout(objects: [booth]))
        let issue = try #require(issues.first { $0.kind == .belowMinimumSize })

        #expect(issue.objectIDs == [booth.id])
        #expect(issue.message.contains("N4"))
        #expect(!issue.message.contains("this booth"))
    }

    @Test("outsideFloor and overlappingObjects messages name object labels")
    func outsideFloorAndOverlapMessagesNameObjectLabels() throws {
        let outsideBooth = makeObject(.booth, "N5", center: SIMD2(25, 25), size: SIMD2(2, 2), openSides: .all)
        let overlapA = makeObject(.booth, "N6", center: SIMD2(5, 5), size: SIMD2(2, 2), openSides: [.top])
        let overlapB = makeObject(.booth, "N7", center: SIMD2(6, 5), size: SIMD2(2, 2), openSides: [.bottom])
        let issues = LayoutValidator.issues(in: makeLayout(objects: [outsideBooth, overlapA, overlapB]))
        let outside = try #require(issues.first { $0.kind == .outsideFloor })
        let overlap = try #require(issues.first { $0.kind == .overlappingObjects })

        #expect(outside.message.contains("N5"))
        #expect(overlap.message.contains("N6"))
        #expect(overlap.message.contains("N7"))
        #expect(issues.allSatisfy { !$0.message.contains("this booth") })
    }

    @Test("Blank labels fall back to kind displayName in validation messages")
    func blankLabelsFallBackToDisplayName() throws {
        let booth = makeObject(.booth, "   ", center: SIMD2(25, 25), size: SIMD2(0.3, 2.0))
        let block = makeObject(.block, "", center: SIMD2(25, 25), size: SIMD2(2, 2))
        let issues = LayoutValidator.issues(in: makeLayout(objects: [booth, block]))

        let noOpen = try #require(issues.first { $0.kind == .noOpenSides })
        let minSize = try #require(issues.first { $0.kind == .belowMinimumSize })
        let outside = try #require(issues.first { $0.kind == .outsideFloor })
        let overlap = try #require(issues.first { $0.kind == .overlappingObjects })

        #expect(noOpen.message == "Visitors cannot reach Booth")
        #expect(minSize.message.contains("Booth"))
        #expect(outside.message.contains("Booth"))
        #expect(overlap.objectIDs == [booth.id])
        #expect(overlap.message.contains("Booth"))
        #expect(overlap.message.contains("Object"))
        #expect(issues.allSatisfy { !$0.message.contains("this booth") })
    }
}
