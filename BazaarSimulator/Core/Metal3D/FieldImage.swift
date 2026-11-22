import AppKit
import CoreGraphics
import simd
import SwiftUI

/// Paints a grid of values (crowd density, or how often paths were walked) over the floor as an image
/// the size of the walkable mask. Cells that are not floor stay transparent, and the values between the
/// grid's own cells are blended, so the heat is smooth and stays off the walls.
enum FieldImage {
    enum Kind { case density, footfall }

    private static let rampSteps = 256
    /// The heat scale as bytes, taken from `HeatScale` so the 3D scene and the legend agree.
    private static let ramp: [SIMD3<Float>] = (0..<rampSteps).map { step in
        let color = NSColor(HeatScale.color(forLevel: Double(step) / Double(rampSteps - 1))).usingColorSpace(.sRGB) ?? .white
        return SIMD3(Float(color.redComponent), Float(color.greenComponent), Float(color.blueComponent))
    }
    private static let footfallRamp: [SIMD3<Float>] = (0..<rampSteps).map { step in
        let color = NSColor(HeatScale.footfallColor(forLevel: Double(step) / Double(rampSteps - 1))).usingColorSpace(.sRGB) ?? .white
        return SIMD3(Float(color.redComponent), Float(color.greenComponent), Float(color.blueComponent))
    }

    /// The painted floor as raw bytes: red, green, blue, alpha for each cell, row by row, with each color
    /// already multiplied by its alpha.
    struct Pixels: Equatable {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    /// The same image as a `CGImage`.
    static func make(
        kind: Kind,
        values: [Float],
        columns: Int,
        rows: Int,
        scale: SIMD2<Float> = SIMD2(1, 1),
        mask: WalkableMask
    ) -> CGImage? {
        guard let pixels = pixels(kind: kind, values: values, columns: columns, rows: rows, scale: scale, mask: mask) else {
            return nil
        }
        let width = pixels.width, height = pixels.height
        var bytes = pixels.bytes
        return bytes.withUnsafeMutableBytes { bytes -> CGImage? in
            CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
    }

    /// `values` is `columns` by `rows`, row by row. `scale` maps a share of the plan to a share of the
    /// grid, for grids slightly larger than the plan. Returns nil if the sizes do not fit.
    static func pixels(
        kind: Kind,
        values: [Float],
        columns: Int,
        rows: Int,
        scale: SIMD2<Float> = SIMD2(1, 1),
        mask: WalkableMask
    ) -> Pixels? {
        guard columns > 0, rows > 0, values.count == columns * rows,
              mask.columns > 0, mask.rows > 0, mask.cells.count == mask.columns * mask.rows else { return nil }

        var pixels = [UInt8](repeating: 0, count: mask.columns * mask.rows * 4)
        for row in 0..<mask.rows {
            for column in 0..<mask.columns where mask.cells[row * mask.columns + column] {
                let share = SIMD2(
                    (Float(column) + 0.5) / Float(mask.columns) * scale.x,
                    (Float(row) + 0.5) / Float(mask.rows) * scale.y
                )
                let value = sample(values, columns: columns, rows: rows, at: share)
                let (level, alpha) = paint(kind, value)
                guard alpha > 0 else { continue }
                let palette = kind == .footfall ? footfallRamp : ramp
                let color = palette[min(max(Int(level * Float(rampSteps - 1) + 0.5), 0), rampSteps - 1)]
                let index = (row * mask.columns + column) * 4
                // Premultiplied by alpha, as the image format expects.
                pixels[index] = UInt8(min(color.x * alpha, 1) * 255 + 0.5)
                pixels[index + 1] = UInt8(min(color.y * alpha, 1) * 255 + 0.5)
                pixels[index + 2] = UInt8(min(color.z * alpha, 1) * 255 + 0.5)
                pixels[index + 3] = UInt8(alpha * 255 + 0.5)
            }
        }
        return Pixels(width: mask.columns, height: mask.rows, bytes: pixels)
    }

    /// The heat level (0 green to 1 red) and how opaque it is, for one value.
    static func paint(_ kind: Kind, _ value: Float) -> (level: Float, alpha: Float) {
        switch kind {
        case .density:
            let level = Float(HeatScale.level(forDensity: Double(value)))
            return (level, (0.4 + 0.45 * level) * smoothstep(0, 0.15, value))
        case .footfall:
            let level = min(max(value, 0), 1)
            let alpha = Float(HeatScale.footfallAlpha(forLevel: Double(level))) * smoothstep(0, 0.02, level)
            return (level, alpha)
        }
    }

    private static func smoothstep(_ low: Float, _ high: Float, _ value: Float) -> Float {
        let t = min(max((value - low) / (high - low), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// The value at `share` (0 to 1 across and down the grid), blended between the four nearest cells.
    private static func sample(_ values: [Float], columns: Int, rows: Int, at share: SIMD2<Float>) -> Float {
        let x = min(max(share.x * Float(columns) - 0.5, 0), Float(columns - 1))
        let y = min(max(share.y * Float(rows) - 0.5, 0), Float(rows - 1))
        let x0 = Int(x), y0 = Int(y)
        let x1 = min(x0 + 1, columns - 1), y1 = min(y0 + 1, rows - 1)
        let tx = x - Float(x0), ty = y - Float(y0)
        let top = values[y0 * columns + x0] * (1 - tx) + values[y0 * columns + x1] * tx
        let bottom = values[y1 * columns + x0] * (1 - tx) + values[y1 * columns + x1] * tx
        return top * (1 - ty) + bottom * ty
    }
}
