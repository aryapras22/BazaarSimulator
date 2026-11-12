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
        let food = LegendEntry(name: "Food", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        var strong = Self.booth(at: SIMD2(6, 6))
        strong.categoryID = food.id
        strong.attractiveness = 4
        var weak = Self.booth(at: SIMD2(12, 6))
        weak.categoryID = food.id
        weak.attractiveness = 1
        let simulation = makeSimulation(objects: [strong, weak], legend: Legend(entries: [food]), buyerOnly: true)

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
        let food = LegendEntry(name: "Food", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        var booth = Self.booth(at: SIMD2(6, 6))
        booth.categoryID = food.id
        let table = LayoutObject(
            kind: .table,
            label: "Table",
            placement: Placement(center: SIMD2(12, 6), sizeM: SIMD2(1, 1))
        )
        let simulation = makeSimulation(objects: [booth, table], legend: Legend(entries: [food]))
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
            settings.strollerWeight = 0
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
            "stage", label: "Stage", placement: Placement(center: center, sizeM: SIMD2(2, 2))
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

    @Test("A stopover at entertainment leaves the stroller's stopovers untouched")
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

    @Test("A party sits on the chairs of a seating group big enough for it")
    func partySitsOnSeatingBlock() throws {
        let food = LegendEntry(name: "Food", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        var booth = Self.booth(at: SIMD2(6, 6))
        booth.categoryID = food.id
        let seating = LayoutObject(
            kind: .seating,
            label: "Seats",
            placement: Placement(center: SIMD2(12, 6), sizeM: SIMD2(2.5, 0.5)),
            catalogID: FurnitureModels.seatingBlockID
        )
        let simulation = makeSimulation(objects: [booth, seating], legend: Legend(entries: [food]))
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
