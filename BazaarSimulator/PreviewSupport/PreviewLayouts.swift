import Foundation
import simd

enum PreviewLayouts {
    static let sampleLegend = Legend(entries: [
        LegendEntry(
            name: "Food & Beverage",
            color: LegendColor(red: 222 / 255.0, green: 42 / 255.0, blue: 42 / 255.0),
            type: .fnb
        ),
        LegendEntry(
            name: "Fashion & Beauty",
            color: LegendColor(red: 42 / 255.0, green: 222 / 255.0, blue: 49 / 255.0),
            type: .goods
        ),
        LegendEntry(
            name: "Lifestyle & Hobbies",
            color: LegendColor(red: 244 / 255.0, green: 220 / 255.0, blue: 48 / 255.0),
            type: .goods
        )
    ])

    static func smallMarket() -> Layout {
        let hall: [SIMD2<Double>] = [
            SIMD2<Double>(1, 1), SIMD2<Double>(29, 1),
            SIMD2<Double>(29, 20), SIMD2<Double>(1, 20)
        ]
        let lobby: [SIMD2<Double>] = [
            SIMD2<Double>(10, 20.2), SIMD2<Double>(29, 20.2),
            SIMD2<Double>(29, 28), SIMD2<Double>(12, 28), SIMD2<Double>(10, 26)
        ]
        let markers: [LayoutMarker] = [
            LayoutMarker(kind: .spawn, label: "Entrance", position: SIMD2<Double>(27.5, 23)),
            LayoutMarker(kind: .exit, label: "Exit", position: SIMD2<Double>(27.5, 26))
        ]
        let zones: [LayoutZone] = [
            LayoutZone(label: "FOYER", minX: 16, maxX: 29, labelPosition: SIMD2<Double>(22, 24))
        ]
        return Layout(
            name: "Preview Market",
            sizeM: SIMD2<Double>(30, 30),
            hall: hall,
            lobby: lobby,
            objects: smallMarketObjects(),
            markers: markers,
            zones: zones
        )
    }

    static func annyeong() -> Layout {
        guard let dto = try? MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout") else {
            return smallMarket()
        }
        return MockLayoutMapper.layout(from: dto, legend: sampleLegend)
    }

    static func beyond() -> Layout {
        guard let dto = try? MockDataStore.load(BazaarLayoutDTO.self, from: "beyond-market-layout") else {
            return smallMarket()
        }
        return MockLayoutMapper.layout(from: dto, legend: sampleLegend)
    }

    private static func smallMarketObjects() -> [LayoutObject] {
        let foodID = sampleLegend.entries.first?.id
        return [
            LayoutObject(
                kind: .wall,
                label: "Lobby wall",
                placement: Placement(center: SIMD2<Double>(19.5, 20.1), sizeM: SIMD2<Double>(19, 0.4))
            ),
            LayoutObject(
                kind: .door,
                label: "Door NW",
                placement: Placement(center: SIMD2<Double>(14, 20.1), sizeM: SIMD2<Double>(2, 0.5)),
                doorFlow: DoorFlow(direction: .both, connection: .hallToLobby)
            ),
            LayoutObject(
                kind: .door,
                label: "Door NE",
                placement: Placement(center: SIMD2<Double>(24, 20.1), sizeM: SIMD2<Double>(2, 0.5)),
                doorFlow: DoorFlow(direction: .exit, connection: .hallToLobby)
            ),
            LayoutObject(
                kind: .booth,
                label: "B7",
                placement: Placement(center: SIMD2<Double>(8, 8), sizeM: SIMD2<Double>(2, 2)),
                categoryID: foodID,
                boothType: .fnb,
                openSides: [.right, .bottom]
            ),
            LayoutObject(
                kind: .booth,
                label: "A1",
                placement: Placement(center: SIMD2<Double>(12, 8), sizeM: SIMD2<Double>(2.5, 2.5)),
                openSides: [.top, .bottom, .left, .right]
            ),
            LayoutObject(
                kind: .block,
                label: "Stage",
                placement: Placement(center: SIMD2<Double>(4, 14), sizeM: SIMD2<Double>(4, 6))
            )
        ]
    }
}
