import simd
import Testing
@testable import BazaarSimulator

@Suite
struct StageOrientationTests {
    private static let quarterTurnRotations = [0, 90, 180, 270]

    private func makeStage(
        openSides: OpenSides,
        rotationDegrees: Int,
        size: SIMD2<Double> = SIMD2(6, 3)
    ) -> LayoutObject {
        LayoutObject(
            kind: .entertainment,
            label: "Stage",
            placement: Placement(
                center: SIMD2(10, 8),
                sizeM: size,
                rotationRadians: Double(rotationDegrees) * .pi / 180
            ),
            openSides: openSides,
            catalogID: EntertainmentType.stage.catalogID
        )
    }

    private func screenDirection(for screenSide: OpenSides) -> SIMD2<Float> {
        switch screenSide {
        case .top: SIMD2(0, -1)
        case .right: SIMD2(1, 0)
        case .bottom: SIMD2(0, 1)
        case .left: SIMD2(-1, 0)
        default: SIMD2(0, 0)
        }
    }

    private func oppositeSide(of side: OpenSides) -> OpenSides {
        switch side {
        case .top: .bottom
        case .right: .left
        case .bottom: .top
        case .left: .right
        default: .bottom
        }
    }

    private func assertStageFacing(
        _ stage: LayoutObject,
        expectedLocalFront: OpenSides,
        rotationDegrees: Int,
        expectedScreenSide: OpenSides? = nil
    ) throws {
        let screenSide = expectedScreenSide ?? expectedLocalFront.rotatedToScreen(byDegrees: rotationDegrees)
        let expectedDirection = screenDirection(for: screenSide)
        let context = "open=\(stage.openSides.rawValue) front=\(expectedLocalFront.rawValue) rot=\(rotationDegrees)°"

        let strip = LayoutGeometry.stripPlacement(for: expectedLocalFront, of: stage.placement, depthM: 0.5)
        let toStrip = SIMD2<Float>(
            Float(strip.center.x - stage.placement.center.x),
            Float(strip.center.y - stage.placement.center.y)
        )
        #expect(simd_dot(simd_normalize(toStrip), expectedDirection) > 0.999, "\(context): screen side matches plan")

        let blocks = VenueGeometry.blocks(for: stage)
        let deck = try #require(blocks.first { $0.color == VenueGeometry.coralColor }, "\(context): deck block")
        let deckForward = SIMD2<Float>(sin(deck.rotationY), cos(deck.rotationY))
        #expect(simd_dot(deckForward, expectedDirection) > 0.999, "\(context): deck turn faces expected screen side")

        let steps = blocks.filter { $0.color == VenueGeometry.creamColor }
        #expect(steps.count == 2, "\(context): stage has two front steps")

        let halfDepth: Float = (expectedLocalFront == .left || expectedLocalFront == .right)
            ? Float(stage.placement.sizeM.x / 2)
            : Float(stage.placement.sizeM.y / 2)

        for step in steps {
            let offset = SIMD2<Float>(
                step.center.x - Float(stage.placement.center.x),
                step.center.z - Float(stage.placement.center.y)
            )
            #expect(simd_dot(simd_normalize(offset), expectedDirection) > 0.999, "\(context): step on open side")
            #expect(simd_dot(offset, expectedDirection) > halfDepth, "\(context): step sits outside deck")
        }

        let backdrops = blocks.filter { $0.color == VenueGeometry.cobaltColor }
        #expect(backdrops.count == 1, "\(context): stage has one backdrop")
        let backdrop = try #require(backdrops.first)
        let backOffset = SIMD2<Float>(
            backdrop.center.x - Float(stage.placement.center.x),
            backdrop.center.z - Float(stage.placement.center.y)
        )
        #expect(simd_dot(simd_normalize(backOffset), -expectedDirection) > 0.999, "\(context): backdrop opposite front")
        #expect(simd_dot(backOffset, expectedDirection) < 0, "\(context): backdrop behind center")
    }

    @Test("Every single open side faces its rotated screen side across all four quarter-turn rotations")
    func singleOpenSideAllRotations() throws {
        for side in OpenSides.ordered {
            for degrees in Self.quarterTurnRotations {
                let stage = makeStage(openSides: side, rotationDegrees: degrees)
                try assertStageFacing(stage, expectedLocalFront: side, rotationDegrees: degrees)
            }
        }
    }

    @Test("Clockwise plan rotation turns a stage front identically to OpenSides screen mapping")
    func turnDirectionMatchesScreenSideMapping() throws {
        let clockwiseSequences: [(local: OpenSides, screens: [OpenSides])] = [
            (.top, [.top, .right, .bottom, .left]),
            (.right, [.right, .bottom, .left, .top]),
            (.bottom, [.bottom, .left, .top, .right]),
            (.left, [.left, .top, .right, .bottom])
        ]

        for entry in clockwiseSequences {
            for (degrees, expectedScreen) in zip(Self.quarterTurnRotations, entry.screens) {
                #expect(entry.local.rotatedToScreen(byDegrees: degrees) == expectedScreen)
                let stage = makeStage(openSides: entry.local, rotationDegrees: degrees)
                try assertStageFacing(
                    stage,
                    expectedLocalFront: entry.local,
                    rotationDegrees: degrees,
                    expectedScreenSide: expectedScreen
                )
            }
        }
    }

    @Test("Three open sides face opposite the single closed back side across all four rotations")
    func threeOpenSidesFaceAwayFromClosedBack() throws {
        for closedSide in OpenSides.ordered {
            let openSides = OpenSides.all.subtracting(closedSide)
            let expectedFront = oppositeSide(of: closedSide)
            for degrees in Self.quarterTurnRotations {
                let stage = makeStage(openSides: openSides, rotationDegrees: degrees)
                try assertStageFacing(stage, expectedLocalFront: expectedFront, rotationDegrees: degrees)
            }
        }
    }

    @Test("Two adjacent open sides on a non-square footprint face along the longer edge")
    func twoAdjacentOpenSidesPreferLongerEdge() throws {
        let wideCases: [(OpenSides, OpenSides)] = [
            ([.top, .right], .top),
            ([.top, .left], .top),
            ([.bottom, .right], .bottom),
            ([.bottom, .left], .bottom)
        ]
        for (openSides, expectedFront) in wideCases {
            for degrees in Self.quarterTurnRotations {
                let stage = makeStage(openSides: openSides, rotationDegrees: degrees, size: SIMD2(6, 3))
                try assertStageFacing(stage, expectedLocalFront: expectedFront, rotationDegrees: degrees)
            }
        }

        let tallCases: [(OpenSides, OpenSides)] = [
            ([.top, .right], .right),
            ([.top, .left], .left),
            ([.bottom, .right], .right),
            ([.bottom, .left], .left)
        ]
        for (openSides, expectedFront) in tallCases {
            for degrees in Self.quarterTurnRotations {
                let stage = makeStage(openSides: openSides, rotationDegrees: degrees, size: SIMD2(3, 6))
                try assertStageFacing(stage, expectedLocalFront: expectedFront, rotationDegrees: degrees)
            }
        }
    }

    @Test("Tied adjacent pairs and opposite open pairs fall back to bottom-top-left-right priority")
    func twoOpenSidesTieAndOppositeFallback() throws {
        let squareCases: [(OpenSides, OpenSides)] = [
            ([.bottom, .right], .bottom),
            ([.bottom, .left], .bottom),
            ([.top, .right], .top),
            ([.top, .left], .top)
        ]
        for (openSides, expectedFront) in squareCases {
            for degrees in Self.quarterTurnRotations {
                let stage = makeStage(openSides: openSides, rotationDegrees: degrees, size: SIMD2(4, 4))
                try assertStageFacing(stage, expectedLocalFront: expectedFront, rotationDegrees: degrees)
            }
        }

        for degrees in Self.quarterTurnRotations {
            let verticalPair = makeStage(openSides: [.top, .bottom], rotationDegrees: degrees, size: SIMD2(3, 6))
            try assertStageFacing(verticalPair, expectedLocalFront: .bottom, rotationDegrees: degrees)

            let horizontalPair = makeStage(openSides: [.left, .right], rotationDegrees: degrees, size: SIMD2(6, 3))
            try assertStageFacing(horizontalPair, expectedLocalFront: .left, rotationDegrees: degrees)
        }
    }

    @Test("Zero or four open sides fall back to facing local bottom across all rotations")
    func zeroOrAllOpenSidesFallbackToBottom() throws {
        for openSides in [OpenSides(), OpenSides.all] {
            for degrees in Self.quarterTurnRotations {
                let stage = makeStage(openSides: openSides, rotationDegrees: degrees)
                try assertStageFacing(stage, expectedLocalFront: .bottom, rotationDegrees: degrees)
            }
        }
    }
}
