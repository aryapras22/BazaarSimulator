import AppKit
import SpriteKit

enum VisitorDots {
    static func color(for state: VisitorState) -> NSColor {
        switch state {
        case .walking: return .systemBlue
        case .queueing: return .systemOrange
        case .browsing: return .systemPurple
        case .seated: return .systemTeal
        case .exiting: return .systemGreen
        }
    }

    /// One shared texture lets SpriteKit draw every visitor in a single batch.
    static func makeTexture() -> SKTexture {
        let side = 32
        let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(.white)
        context?.fillEllipse(in: CGRect(x: 1, y: 1, width: side - 2, height: side - 2))
        guard let image = context?.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }
}
