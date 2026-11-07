import CoreGraphics
import Foundation
import PDFKit

enum PDFImportError: Error {
    case unreadable
}

protocol PDFImporting: Sendable {
    func renderFirstPage(of url: URL) throws -> CGImage
}

/// The extractor was tuned on plans about 2300 x 2900 px, so pages are drawn with their long side at this size.
struct PDFImportService: PDFImporting {
    static let longSidePixels = 2800

    func renderFirstPage(of url: URL) throws -> CGImage {
        // The page draws from its document, so the document has to outlive the draw call below.
        let document = PDFDocument(url: url)
        guard let page = document?.page(at: 0) else { throw PDFImportError.unreadable }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { throw PDFImportError.unreadable }

        let scale = CGFloat(Self.longSidePixels) / max(bounds.width, bounds.height)
        let width = Int((bounds.width * scale).rounded())
        let height = Int((bounds.height * scale).rounded())
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw PDFImportError.unreadable }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        withExtendedLifetime(document) { page.draw(with: .mediaBox, to: context) }
        guard let image = context.makeImage() else { throw PDFImportError.unreadable }
        return image
    }
}
