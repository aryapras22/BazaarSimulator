import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("CrowdSimulation Tests")
@MainActor
struct CrowdSimulationTests {

    @Test("Walking speed slows with density along the Weidmann curve")
    func crowdFactorFollowsWeidmann() {
        #expect(CrowdSimulation.crowdFactor(density: 0.01) == 1)
        #expect(abs(CrowdSimulation.crowdFactor(density: 1.0) - 0.790) < 0.001)
        #expect(CrowdSimulation.crowdFactor(density: 6.0) == CrowdParameters.minimumCrowdFactor)
    }

    @Test("Groups walk wider when quiet and closer when busy")
    func spacingClosesUpWhenBusy() {
        #expect(CrowdSimulation.sideSpacing(density: 0.1) == 0.855)
        #expect(CrowdSimulation.sideSpacing(density: 1.0) == 0.605)
        #expect(abs(CrowdSimulation.sideSpacing(density: 0.495) - 0.73) < 0.001)
    }

    @Test("Time to collision is the moment two circles first touch")
    func timeToCollision() {
        let approaching = CrowdSimulation.timeToCollision(offset: SIMD2(5, 0), relativeVelocity: SIMD2(1, 0), radius: 1)
        let leaving = CrowdSimulation.timeToCollision(offset: SIMD2(5, 0), relativeVelocity: SIMD2(-1, 0), radius: 1)

        #expect(abs(approaching - 4) < 0.001)
        #expect(leaving == .infinity)
    }

    @Test("Helbing social repulsion force pushes away and is stronger for pedestrians in front than behind")
    func socialRepulsionForceAnisotropy() {
        let inFront = CrowdSimulation.socialRepulsionForce(
            offsetToNeighbor: SIMD2(0.6, 0),
            combinedRadius: 0.5,
            forwardDirection: SIMD2(1, 0)
        )
        let behind = CrowdSimulation.socialRepulsionForce(
            offsetToNeighbor: SIMD2(-0.6, 0),
            combinedRadius: 0.5,
            forwardDirection: SIMD2(1, 0)
        )

        #expect(inFront.x < 0)
        #expect(behind.x > 0)
        #expect(simd_length(inFront) > simd_length(behind))
    }

    @Test("Families are two adults with one or two kids, and no party passes four people")
    func partyComposition() {
        let simulation = makeSimulation()
        for _ in 0..<2000 {
            let draw = simulation.drawParty(limit: 100)
            #expect(draw.people <= 4)
            if draw.kind == .family {
                #expect(draw.adults == 2)
                #expect((1...2).contains(draw.kids))
            }
        }
    }

    @Test("A party never exceeds the visitors still to come", arguments: [1, 2, 3])
    func partyRespectsLimit(limit: Int) {
        let simulation = makeSimulation()
        for _ in 0..<300 {
            #expect(simulation.drawParty(limit: limit).people <= limit)
        }
    }

    @Test("Speed follows the group type")
    func speedByGroupType() {
        #expect(CrowdSimulation.baseSpeed(for: .alone) == 1.52)
        #expect(CrowdSimulation.baseSpeed(for: .friends) == 1.36)
        #expect(CrowdSimulation.baseSpeed(for: .family) == 1.39)
    }

    @Test("A planned food buyer picks food booths in proportion to pull")
    func plansFollowFoodShareAndPull() {
        var strong = Self.booth(at: SIMD2(6, 6))
        strong.boothType = .fnb
        strong.attractiveness = 4
        var weak = Self.booth(at: SIMD2(12, 6))
        weak.boothType = .fnb
        weak.attractiveness = 1
        let simulation = makeSimulation(objects: [strong, weak], buyerOnly: true)

        var strongFirst = 0
        for _ in 0..<400 {
            let party = spawnedParty(in: simulation)
            if party.plan.count == 1 && party.plan[0] == 0 { strongFirst += 1 }
        }

        #expect(strongFirst > 120)
    }

    @Test("A full queue makes the party skip the booth")
    func fullQueueBalks() {
        let simulation = makeSimulation(objects: [Self.booth(at: SIMD2(10, 10))])
        let waiting = (0..<6).map { _ in spawnedParty(in: simulation) }
        simulation.queues[0] = waiting
        let arriving = spawnedParty(in: simulation)
        arriving.target = .booth(0, .planned)

        simulation.arrive(arriving)

        #expect(simulation.stats.balks == 1)
        #expect(arriving.visited.contains(0))
    }

    @Test("A loyal buyer keeps to the plan and a disloyal one detours to a stronger booth in view")
    func detoursDependOnLoyalty() {
        var planned = Self.booth(at: SIMD2(18, 2))
        planned.attractiveness = 1
        var strong = Self.booth(at: SIMD2(6, 2))
        strong.attractiveness = 5
        let simulation = makeSimulation(objects: [planned, strong])

        let loyal = spawnedParty(in: simulation)
        loyal.isGoalDriven = true
        loyal.loyalty = 5
        loyal.target = .booth(0, .planned)
        loyal.heading = 0
        simulation.considerDetour(loyal)

        let disloyal = spawnedParty(in: simulation)
        disloyal.isGoalDriven = true
        disloyal.loyalty = 1
        disloyal.target = .booth(0, .planned)
        disloyal.heading = 0
        simulation.considerDetour(disloyal)

        if case .booth(0, .planned) = loyal.target {} else { Issue.record("Loyal party left its plan") }
        if case .booth(1, .detour) = disloyal.target {} else { Issue.record("Disloyal party did not detour") }
    }

    @Test("A booth outside the view cone does not draw the party")
    func boothBehindIsNotSeen() {
        var strong = Self.booth(at: SIMD2(18, 2))
        strong.attractiveness = 5
        let simulation = makeSimulation(objects: [strong])
        let party = spawnedParty(in: simulation)
        party.leader.position = SIMD2(4, 2)
        party.heading = .pi

        #expect(simulation.bestVisibleBooth(for: party) == nil)
    }

    @Test("A food buyer who wants to sit walks to a free table after the booth")
    func foodBuyerGoesToTable() {
        var booth = Self.booth(at: SIMD2(6, 6))
        booth.boothType = .fnb
        let table = LayoutObject(
            kind: .table,
            label: "Table",
            placement: Placement(center: SIMD2(12, 6), sizeM: SIMD2(1, 1))
        )
        let simulation = makeSimulation(objects: [booth, table])
        let party = spawnedParty(in: simulation)
        party.target = .booth(0, .planned)
        simulation.startVisit(party, booth: 0)
        party.willSit = true

        simulation.finishStop(party)

        if case .table(0) = party.target {} else { Issue.record("Party did not head for the table") }
        #expect(simulation.tableOccupants[0] === party)
    }

    @Test("A person cannot walk into an exit-only door from outside")
    func exitOnlyDoorStopsInboundStep() throws {
        let door = LayoutObject(
            kind: .door,
            label: "Door",
            placement: Placement(center: SIMD2(10, 10), sizeM: SIMD2(2, 0.5)),
            doorFlow: DoorFlow(direction: .exit, connection: .hallToLobby)
        )
        let layout = Layout(
            name: "Rooms",
            sizeM: SIMD2(20, 20),
            hall: [SIMD2(1, 1), SIMD2(19, 1), SIMD2(19, 9.9), SIMD2(1, 9.9)],
            lobby: [SIMD2(1, 10.1), SIMD2(19, 10.1), SIMD2(19, 19), SIMD2(1, 19)],
            objects: [door],
            markers: [LayoutMarker(kind: .spawn, label: "In", position: SIMD2(4, 16))],
            zones: []
        )
        let simulation = CrowdSimulation(world: CrowdWorld(layout: layout), settings: SimulationSettings())
        let agent = spawnedParty(in: simulation).leader
        let start = SIMD2(10.0, 10.75)
        agent.position = SIMD2(10.0, 10.25)

        simulation.applyDoorRule(position: &agent.position, velocity: &agent.velocity, from: start)

        #expect(agent.position.y == start.y)
    }

    @Test("Everyone who enters leaves, and nobody ends up inside an obstacle")
    func fullRunEmptiesTheHall() {
        let settings = SimulationSettings(totalVisitors: 120, arrivalsPer15Min: 120, randomSeed: 11)
        let simulation = CrowdSimulation(world: CrowdWorld(layout: PreviewLayouts.smallMarket()), settings: settings)

        for tick in 0..<(3 * 3600 * CrowdParameters.stepsPerSecond) {
            simulation.step()
            if tick % CrowdParameters.stepsPerSecond == 0 {
                for agent in simulation.agents where !agent.isSeated {
                    #expect(simulation.world.wallDistance(at: agent.position) > -0.3)
                }
            }
            if simulation.stats.enteredPeople == 120 && simulation.parties.isEmpty { break }
        }

        #expect(simulation.stats.enteredPeople == 120)
        #expect(simulation.stats.departedPeople == 120)
        #expect(simulation.stats.visits > 0)
    }

    private func makeSimulation(
        objects: [LayoutObject] = [],
        legend: Legend = Legend(),
        buyerOnly: Bool = false
    ) -> CrowdSimulation {
        let layout = Layout(
            name: "Floor",
            sizeM: SIMD2(20, 20),
            hall: [],
            lobby: [],
            objects: objects,
            markers: [
                LayoutMarker(kind: .spawn, label: "In", position: SIMD2(2, 2)),
                LayoutMarker(kind: .exit, label: "Out", position: SIMD2(18, 18))
            ],
            zones: []
        )
        var settings = SimulationSettings(randomSeed: 5)
        if buyerOnly {
            settings.socializerWeight = 0
            settings.familyWeight = 0
            settings.explorerWeight = 0
            settings.buyerWeight = 1
        }
        return CrowdSimulation(world: CrowdWorld(layout: layout, legend: legend), settings: settings)
    }

    private func spawnedParty(in simulation: CrowdSimulation) -> CrowdParty {
        simulation.gateTokens[0] = 100
        let draw = simulation.drawParty(limit: 1)
        simulation.agents.removeAll()
        simulation.spawn(draw, atGate: 0)
        return simulation.parties[simulation.parties.count - 1]
    }

    private static func stage(at center: SIMD2<Double>) -> LayoutObject {
        ObjectCatalog.detectedEntertainment(
            label: "Stage", placement: Placement(center: center, sizeM: SIMD2(2, 2))
        )
    }

    private static func booth(at center: SIMD2<Double>) -> LayoutObject {
        LayoutObject(kind: .booth, label: "Booth", placement: Placement(center: center, sizeM: SIMD2(2, 2)))
    }
}

extension CrowdSimulationTests {
    @Test("Entertainment is never one of the planned booths")
    func entertainmentIsNotPlanned() {
        let simulation = makeSimulation(objects: [Self.booth(at: SIMD2(6, 6)), Self.stage(at: SIMD2(12, 6))])

        for _ in 0..<200 {
            #expect(!spawnedParty(in: simulation).plan.contains(1))
        }
    }

    @Test("A buyer with no detour left still stops at entertainment and keeps the planned booth")
    func entertainmentDetourIsFree() {
        var planned = Self.booth(at: SIMD2(18, 2))
        planned.attractiveness = 1
        let simulation = makeSimulation(objects: [planned, Self.stage(at: SIMD2(6, 2))])
        let party = spawnedParty(in: simulation)
        party.isGoalDriven = true
        party.loyalty = 1
        party.plan = [0]
        party.detours = CrowdParameters.maxDetours
        party.target = .booth(0, .planned)
        party.heading = 0

        simulation.considerDetour(party)

        if case .booth(1, .detour) = party.target {} else { Issue.record("Party did not stop at the stage") }
        #expect(party.plan == [0])
        #expect(party.detours == CrowdParameters.maxDetours)
    }

    @Test("A stopover at entertainment leaves the explorer's stopovers untouched")
    func entertainmentStopoverIsFree() {
        let simulation = makeSimulation(objects: [Self.stage(at: SIMD2(6, 2))])
        let party = spawnedParty(in: simulation)
        party.stopoversLeft = 0
        party.isGoalDriven = false
        party.target = .exit
        party.heading = 0

        simulation.considerDetour(party)
        simulation.startVisit(party, booth: 0)
        simulation.finishStop(party)

        #expect(party.visited.contains(0))
        #expect(party.stopoversLeft == 0)
    }

    @Test("Some entertainment visitors sit in nearby seating to watch, never at a table")
    func stageVisitorsSitAsAudience() {
        let seating = LayoutObject(
            kind: .seating,
            label: "Audience",
            placement: Placement(center: SIMD2(6, 9), sizeM: SIMD2(2, 1)),
            catalogID: FurnitureModels.seatingBlockID
        )
        let table = LayoutObject(
            kind: .table,
            label: "Table",
            placement: Placement(center: SIMD2(6, 13), sizeM: SIMD2(1, 1))
        )
        let simulation = makeSimulation(objects: [Self.stage(at: SIMD2(6, 5)), seating, table])
        var watching = 0

        for _ in 0..<40 {
            let party = spawnedParty(in: simulation)
            party.target = .booth(0, .detour)
            simulation.startVisit(party, booth: 0)
            simulation.finishStop(party)
            if case .table(let group) = party.target {
                #expect(simulation.world.tables[group].isSeating)
                watching += 1
            }
            simulation.tableOccupants = simulation.tableOccupants.map { _ in nil }
        }

        #expect((8...32).contains(watching))
    }

    @Test("A stage with free seating near it is watched from a seat instead of walked up to")
    func stageIsWatchedFromSeating() {
        let seating = LayoutObject(
            kind: .seating,
            label: "Audience",
            placement: Placement(center: SIMD2(6, 5), sizeM: SIMD2(2, 1)),
            catalogID: FurnitureModels.seatingBlockID
        )
        let simulation = makeSimulation(objects: [Self.stage(at: SIMD2(6, 2)), seating])
        let party = spawnedParty(in: simulation)
        party.stopoversLeft = 0
        party.isGoalDriven = false
        party.target = .exit
        party.heading = 0

        simulation.considerDetour(party)

        if case .table(let group) = party.target {
            #expect(simulation.world.tables[group].isSeating)
        } else {
            Issue.record("Party did not head for the seating")
        }
        #expect(party.visited.contains(0))

        // With every seat taken, the next party walks up to the stage as before.
        simulation.tableOccupants = simulation.tableOccupants.map { _ in party }
        let late = spawnedParty(in: simulation)
        late.stopoversLeft = 0
        late.isGoalDriven = false
        late.target = .exit
        late.heading = 0
        simulation.considerDetour(late)
        if case .booth(0, .stopover) = late.target {} else { Issue.record("Party did not go to the stage") }
    }

    @Test("Closing ends every stop, sends everyone to the exit and lets nobody else in")
    func closingSendsEveryoneOut() {
        let simulation = makeSimulation(objects: [Self.booth(at: SIMD2(6, 6))])
        let visiting = spawnedParty(in: simulation)
        visiting.target = .booth(0, .planned)
        simulation.startVisit(visiting, booth: 0)
        let walking = spawnedParty(in: simulation)
        walking.plan = [0]
        walking.target = .booth(0, .planned)

        simulation.startClosing()

        for party in [visiting, walking] {
            if case .exit = party.target {} else { Issue.record("Party is not leaving") }
            #expect(party.state == .walking)
        }
        #expect(simulation.browsers[0].isEmpty)
        let inside = simulation.parties.count
        for _ in 0..<600 { simulation.step() }
        #expect(simulation.parties.count <= inside)
    }

    @Test("A disabled booth is never planned")
    func disabledBoothIsNotPlanned() {
        var closed = Self.booth(at: SIMD2(6, 6))
        closed.isDisabled = true
        let simulation = makeSimulation(objects: [closed, Self.booth(at: SIMD2(12, 6))])

        for _ in 0..<100 {
            #expect(!spawnedParty(in: simulation).plan.contains(0))
        }
        #expect(simulation.world.booths.count == 2, "it still stands on the floor")
    }

    @Test("A party sits on the chairs of a seating group big enough for it")
    func partySitsOnSeatingBlock() throws {
        var booth = Self.booth(at: SIMD2(6, 6))
        booth.boothType = .fnb
        let seating = LayoutObject(
            kind: .seating,
            label: "Seats",
            placement: Placement(center: SIMD2(12, 6), sizeM: SIMD2(2.5, 0.5)),
            catalogID: FurnitureModels.seatingBlockID
        )
        let simulation = makeSimulation(objects: [booth, seating])
        let party = spawnedParty(in: simulation)
        party.target = .booth(0, .planned)
        simulation.startVisit(party, booth: 0)
        party.willSit = true

        simulation.finishStop(party)
        let group = try #require({ if case .table(let index) = party.target { index } else { nil } }())
        simulation.arrive(party)

        #expect(simulation.world.tables[group].seats.count >= party.members.count)
        for (index, member) in party.members.enumerated() {
            #expect(member.position == simulation.world.tables[group].seats[index])
        }
    }
}
