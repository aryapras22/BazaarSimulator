import AppKit
import simd
import SwiftUI
import Testing
@testable import BazaarSimulator

@Suite
struct FieldImageTests {
    private func mask(_ columns: Int, _ rows: Int, floor: [Bool]? = nil) -> WalkableMask {
        WalkableMask(
            origin: .zero, cellSizeM: 0.5, columns: columns, rows: rows,
            cells: floor ?? Array(repeating: true, count: columns * rows)
        )
    }

    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (color: SIMD3<Double>, alpha: Double) {
        let bytes = [UInt8](image.dataProvider!.data! as Data)
        let index = (y * image.width + x) * 4
        let alpha = Double(bytes[index + 3]) / 255
        guard alpha > 0 else { return (.zero, 0) }
        return (SIMD3(Double(bytes[index]), Double(bytes[index + 1]), Double(bytes[index + 2])) / 255 / alpha, alpha)
    }

    private func expected(_ level: Double) -> SIMD3<Double> {
        let color = NSColor(HeatScale.color(forLevel: level)).usingColorSpace(.sRGB)!
        return SIMD3(Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent))
    }

    private func uniform(_ value: Float, kind: FieldImage.Kind, floor: WalkableMask? = nil) -> CGImage? {
        FieldImage.make(kind: kind, values: Array(repeating: value, count: 16), columns: 4, rows: 4, mask: floor ?? mask(8, 8))
    }

    @Test("The image is as big as the floor mask")
    func size() throws {
        let image = try #require(uniform(1, kind: .density, floor: mask(12, 7)))
        #expect(image.width == 12 && image.height == 7)
    }

    @Test("Crowd density takes its color from the heat scale at that density")
    func densityColors() throws {
        for density in [0.2, 0.8, 1.5, 3.0] {
            let image = try #require(uniform(Float(density), kind: .density))
            let level = HeatScale.level(forDensity: density)
            let drawn = pixel(image, 4, 4)
            let want = expected(level)
            #expect(abs(drawn.color.x - want.x) < 0.03 && abs(drawn.color.y - want.y) < 0.03 && abs(drawn.color.z - want.z) < 0.03,
                    "density \(density)")
            #expect(abs(drawn.alpha - (0.4 + 0.45 * level)) < 0.02, "density \(density)")
        }
    }

    @Test("Where nobody stands there is no heat")
    func empty() throws {
        let image = try #require(uniform(0, kind: .density))
        #expect(pixel(image, 4, 4).alpha == 0)
    }

    @Test("Heat stays on the floor")
    func floorOnly() throws {
        let floor = mask(2, 1, floor: [true, false])
        let image = try #require(uniform(1.5, kind: .density, floor: floor))
        #expect(pixel(image, 0, 0).alpha > 0.5)
        #expect(pixel(image, 1, 0).alpha == 0)
    }

    private func expectedFootfall(_ level: Double) -> SIMD3<Double> {
        let color = NSColor(HeatScale.footfallColor(forLevel: level)).usingColorSpace(.sRGB)!
        return SIMD3(Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent))
    }

    @Test("Walked paths run from low-opacity green to bright high-opacity greenish-red")
    func footfallColors() throws {
        var previousAlpha = 0.0
        for share in [Float(0.25), 0.5, 1] {
            let image = try #require(uniform(share, kind: .footfall))
            let drawn = pixel(image, 4, 4)
            let want = expectedFootfall(Double(share))
            #expect(abs(drawn.color.x - want.x) < 0.03 && abs(drawn.color.y - want.y) < 0.03 && abs(drawn.color.z - want.z) < 0.03,
                    "share \(share)")
            #expect(abs(drawn.alpha - HeatScale.footfallAlpha(forLevel: Double(share))) < 0.03)
            #expect(drawn.alpha > previousAlpha)
            previousAlpha = drawn.alpha
        }
        #expect(pixel(try #require(uniform(0, kind: .footfall)), 4, 4).alpha == 0)
    }

    @Test("Values between two grid cells are blended")
    func blends() throws {
        let image = try #require(FieldImage.make(
            kind: .density, values: [0, 0, 3, 3], columns: 2, rows: 2, mask: mask(8, 2)
        ))
        // Row 0 is calm and row 1 is jammed, so the middle is in between.
        let top = pixel(image, 3, 0).alpha
        let bottom = pixel(image, 3, 1).alpha
        #expect(top == 0)
        #expect(bottom > 0.5)
    }

    @Test("A grid larger than the plan is read through its scale")
    func scale() throws {
        // Only the left half of this grid is the plan.
        let image = try #require(FieldImage.make(
            kind: .footfall, values: [1, 1, 0, 0], columns: 4, rows: 1,
            scale: SIMD2(0.5, 1), mask: mask(8, 1)
        ))
        #expect(pixel(image, 0, 0).alpha > 0.5)
        #expect(pixel(image, 7, 0).alpha > 0.4)
    }

    @Test("Sizes that do not fit give no image instead of a crash")
    func badSizes() {
        #expect(FieldImage.make(kind: .density, values: [1, 2, 3], columns: 4, rows: 4, mask: mask(4, 4)) == nil)
        #expect(FieldImage.make(kind: .density, values: [], columns: 0, rows: 0, mask: mask(4, 4)) == nil)
        #expect(FieldImage.make(kind: .density, values: [1], columns: 1, rows: 1, mask: mask(4, 4, floor: [true])) == nil)
    }
}
