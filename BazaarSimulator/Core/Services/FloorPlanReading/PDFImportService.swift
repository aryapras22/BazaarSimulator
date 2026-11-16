import CoreGraphics
import Foundation
import PDFKit

enum PDFImportError: Error {
    case unreadable
    case noPermission
}

protocol PDFImporting: Sendable {
    func renderFirstPage(of url: URL) throws -> CGImage
}

/// A page that is a scan or an exported image is drawn at the pixel size of that image. Shrinking a plan loses its
/// chairs and thin walls to the extractor, and enlarging a legend blurs its swatches until the colours stop matching.
struct PDFImportService: PDFImporting {
    /// A vector page has no pixel size. The extractor was tuned on plans about 2300 x 2900 px.
    static let vectorLongSidePixels = 2800
    private static let aspectTolerance = 0.02

    private func readData(at url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw PDFImportError.noPermission
        } catch {
            throw PDFImportError.unreadable
        }
    }

    func renderFirstPage(of url: URL) throws -> CGImage {
        // The page draws from its document, so the document has to outlive the draw call below.
        let document = PDFDocument(data: try readData(at: url))
        guard let page = document?.page(at: 0) else { throw PDFImportError.unreadable }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { throw PDFImportError.unreadable }

        let scale = Self.pixelsPerPoint(of: page, bounds: bounds)
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

    private static func pixelsPerPoint(of page: PDFPage, bounds: CGRect) -> CGFloat {
        let pageAspect = bounds.width / bounds.height
        let pageImage = page.pageRef.map(imageSizes)?
            .filter { abs($0.width / $0.height - pageAspect) / pageAspect <= aspectTolerance }
            .max { $0.width < $1.width }
        if let pageImage { return pageImage.width / bounds.width }
        return CGFloat(vectorLongSidePixels) / max(bounds.width, bounds.height)
    }

    /// Pixel sizes of the images a page draws. Resources can sit on a parent node of the page tree.
    private static func imageSizes(on page: CGPDFPage) -> [CGSize] {
        var node = page.dictionary
        var resources: CGPDFDictionaryRef?
        while let current = node, !CGPDFDictionaryGetDictionary(current, "Resources", &resources) {
            node = nil
            CGPDFDictionaryGetDictionary(current, "Parent", &node)
        }
        var xObjects: CGPDFDictionaryRef?
        guard let resources, CGPDFDictionaryGetDictionary(resources, "XObject", &xObjects), let xObjects else {
            return []
        }
        var sizes: [CGSize] = []
        CGPDFDictionaryApplyBlock(xObjects, { _, object, _ in
            var stream: CGPDFStreamRef?
            var subtype: UnsafePointer<CChar>?
            var width: CGPDFInteger = 0
            var height: CGPDFInteger = 0
            if CGPDFObjectGetValue(object, .stream, &stream), let stream,
               let dictionary = CGPDFStreamGetDictionary(stream),
               CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype,
               String(cString: subtype) == "Image",
               CGPDFDictionaryGetInteger(dictionary, "Width", &width),
               CGPDFDictionaryGetInteger(dictionary, "Height", &height), width > 0, height > 0 {
                sizes.append(CGSize(width: width, height: height))
            }
            return true
        }, nil)
        return sizes
    }
}
