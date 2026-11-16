import Foundation
import simd
@testable import BazaarSimulator

/// Small hand-built layouts for the simulation tests.
enum TestLayouts {
    static let parameters = EventParameters(
        totalVisitors: 200,
        eventHours: TimeRange(startMinute: 10 * 60, endMinute: 13 * 60),
        bazaarTypeID: "test",
        mix: VisitorMix(equalSplitOf: ["a", "b"])
    )

    static let visitorTypes = [
        VisitorType(id: "a", name: "A", summary: "", walkingSpeedMps: 1.2, plannedStops: 3, dwellMinutes: 2),
        VisitorType(id: "b", name: "B", summary: "", walkingSpeedMps: 1.2, plannedStops: 3, dwellMinutes: 2)
    ]

    /// An open hall with a row of booths along the top wall, an entrance and exit on the left,
    /// and a door in the left wall.
    static func hall(booths: Int = 4, width: Double = 24, depth: Double = 12) -> Layout {
        var objects = (0..<booths).map { index in
            LayoutObject(
                kind: .booth,
                label: "B\(index + 1)",
                placement: Placement(center: SIMD2(4 + 5 * Double(index), 2.5), sizeM: SIMD2(3, 2)),
                openSides: [.bottom]
            )
        }
        objects.append(LayoutObject(
            kind: .door,
            label: "Door A",
            placement: Placement(center: SIMD2(0.2, depth / 2), sizeM: SIMD2(0.6, 2)),
            doorFlow: DoorFlow(direction: .both, connection: .lobbyToOutside)
        ))
        return Layout(
            name: "Test Hall",
            sizeM: SIMD2(width, depth),
            hall: [SIMD2(0, 0), SIMD2(width, 0), SIMD2(width, depth), SIMD2(0, depth)],
            objects: objects,
            markers: [
                LayoutMarker(kind: .spawn, label: "Entrance", position: SIMD2(1, depth / 2)),
                LayoutMarker(kind: .exit, label: "Exit", position: SIMD2(1, depth / 2 + 1))
            ]
        )
    }
}
