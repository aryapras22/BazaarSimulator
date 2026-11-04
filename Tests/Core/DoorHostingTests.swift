import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct DoorHostingTests {
    private func makeLayout() -> Layout {
        // Hall: (0, 0) to (20, 20)
        let hall = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(20, 0),
            SIMD2<Double>(20, 20),
            SIMD2<Double>(0, 20)
        ]
        // Lobby: (0, 20) to (20, 25) adjacent to hall's top edge (y = 20)
        let lobby = [
            SIMD2<Double>(0, 20),
            SIMD2<Double>(20, 20),
            SIMD2<Double>(20, 25),
            SIMD2<Double>(0, 25)
        ]
        // Wall on boundary y = 20
        let wallPlacement = Placement(
            center: SIMD2<Double>(10, 20),
            sizeM: SIMD2<Double>(10, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Lobby Wall", placement: wallPlacement)

        return Layout(
            id: UUID(),
            name: "Test Layout",
            sizeM: SIMD2<Double>(20, 25),
            hall: hall,
            lobby: lobby,
            objects: [wall],
            markers: []
        )
    }

    @Test("The lobby wall hosts hallToLobby")
    func lobbyWallHostsHallToLobby() {
        let layout = makeLayout()
        let host = DoorHosting.nearestHost(to: SIMD2<Double>(10, 20.1), in: layout)
        #expect(host != nil)
        #expect(host?.connection == .hallToLobby)
    }

    @Test("A hall outer edge hosts hallToOutside")
    func hallOuterEdgeHostsHallToOutside() {
        let layout = makeLayout()
        // Bottom edge of hall at y = 0
        let host = DoorHosting.nearestHost(to: SIMD2<Double>(10, 0.2), in: layout)
        #expect(host != nil)
        #expect(host?.connection == .hallToOutside)
    }

    @Test("A lobby edge hosts lobbyToOutside")
    func lobbyEdgeHostsLobbyToOutside() {
        let layout = makeLayout()
        // Top edge of lobby at y = 25
        let host = DoorHosting.nearestHost(to: SIMD2<Double>(10, 24.8), in: layout)
        #expect(host != nil)
        #expect(host?.connection == .lobbyToOutside)
    }

    @Test("A door near a corner is clamped onto its edge")
    func doorNearCornerIsClamped() {
        let host = DoorHost(
            start: SIMD2<Double>(0, 0),
            end: SIMD2<Double>(10, 0),
            connection: .hallToOutside,
            thicknessM: 0.2
        )

        // Door width is 2.0. Point near start at (0.2, 0). Clamped center should be at x = 1.0.
        let placement = DoorHosting.placement(width: 2.0, on: host, near: SIMD2<Double>(0.2, 0))
        #expect(placement != nil)
        #expect(abs(placement!.center.x - 1.0) < 1e-4)
        #expect(abs(placement!.center.y - 0.0) < 1e-4)
        #expect(abs(placement!.sizeM.x - 2.0) < 1e-4)
        #expect(abs(placement!.sizeM.y - 0.3) < 1e-4) // thickness + 0.1
    }
}
