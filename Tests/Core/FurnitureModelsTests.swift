import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct FurnitureModelsTests {
    @Test("Every standard table has as many chairs as its model says, and a seating block one per seat pitch")
    func seatCounts() {
        for model in FurnitureModels.tables {
            #expect(FurnitureModels.seatOffsets(of: model).count == model.seatCount)
        }
        #expect(FurnitureModels.gridOffsets(for: SIMD2(3.0, 2.0)).count == 24)
        #expect(FurnitureModels.gridOffsets(for: SIMD2(0.4, 0.4)).count == 1)
    }

    @Test("Chairs follow their table when it moves and turns")
    func chairsFollowObject() throws {
        var table = LayoutObject(
            kind: .table,
            label: "Table 1",
            placement: Placement(center: SIMD2(10, 10), sizeM: SIMD2(1.2, 0.7)),
            catalogID: "table-rect-2"
        )
        let before = FurnitureModels.chairs(of: table).map(\.center)
        #expect(before.count == 2)
        #expect(abs(before[0].x - 10) < 1e-9)

        table.placement.rotationDegrees = 90
        table.placement.center = SIMD2(20, 10)
        let after = FurnitureModels.chairs(of: table).map(\.center)

        #expect(abs(after[0].y - 10) < 1e-9)
        #expect(abs(abs(after[0].x - 20) - abs(before[0].y - 10)) < 1e-9)
    }

    @Test("Only tables and seating blocks have chairs")
    func otherKindsHaveNone() {
        let booth = LayoutObject(kind: .booth, label: "A1", placement: Placement(center: .zero, sizeM: SIMD2(2, 2)))

        #expect(FurnitureModels.chairs(of: booth).isEmpty)
    }

    @Test("A table is fitted back to its model and angle from where its chairs stand")
    func fitRecoversModelAndAngle() {
        for model in FurnitureModels.tables {
            for angle in [0, 45, 90, 135] {
                let table = LayoutObject(
                    kind: .table,
                    label: "T",
                    placement: Placement(
                        center: SIMD2(5, 7),
                        sizeM: model.sizeM,
                        rotationRadians: Double(angle) * .pi / 180
                    ),
                    catalogID: model.id
                )
                let chairs = FurnitureModels.chairs(of: table).map(\.center)
                let fit = FurnitureFit.best(at: SIMD2(5, 7), chairCentres: chairs)

                #expect(fit.model.id == model.id)
                let symmetric = fit.angleDegrees % 180 == angle % 180 || model.shape == .round
                #expect(symmetric, "\(model.id) at \(angle) fitted at \(fit.angleDegrees)")
            }
        }
    }

    @Test("A table with no chairs still gets a standard model")
    func fitWithoutChairs() {
        let fit = FurnitureFit.best(at: SIMD2(1, 1), chairCentres: [])

        #expect(FurnitureModels.tables.contains { $0.id == fit.model.id })
    }
}
