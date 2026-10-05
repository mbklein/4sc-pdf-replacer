import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import FourScoreKit

/// Builds synthetic `.4sc` files that mirror the structure of a real forScore export
/// (modelled on a sample that can't be committed), so the tests need no fixture files.
enum Fixture {
    static let name = "Test Score.pdf"
    static let pageCount = 4
    static let drawingPages = [2, 3]
    static let drawingSize = (width: 273, height: 357)  // 1/10 of forScore's 2732×3572

    static func key(_ field: String) -> String { "\(name)|\(field)" }
    static func key(page: Int, _ field: String) -> String { "\(name)|\(page)|\(field)" }

    static func plist() -> [String: Any] {
        var dict: [String: Any] = [
            FourScoreFile.pdfDataKey: makePDF(pages: pageCount),
            key("title"): "Test Score",
            key("composer"): "Anonymous",
            key("signature"): "4/4",
            key("bpm"): 80,
            key("keywords"): "test, fixture",
            key(page: 1, "textAnnotations"): [textAnnotation("", x: 0.6, y: 0.5)],
            key(page: 3, "textAnnotations"): [textAnnotation("crescendo", x: 0.5673828125, y: 0.0216)],
        ]
        // forScore writes croppedLandscape for more pages than the PDF has.
        for page in 1...pageCount + 1 { dict[key(page: page, "croppedLandscape")] = 0 }
        for page in drawingPages { dict[key("\(page).png")] = makeDrawingPNG() }
        return dict
    }

    static func data() throws -> Data {
        let raw = try PropertyListSerialization.data(fromPropertyList: plist(), format: .binary, options: 0)
        return try GZip.compress(raw)
    }

    static func file() throws -> FourScoreFile { try FourScoreFile(data: data()) }

    /// Writes a fresh fixture into its own temporary directory.
    static func writeTemporary() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("fixture.4sc")
        try data().write(to: url)
        return url
    }

    static func textAnnotation(_ text: String, x: Double, y: Double) -> [String: Any] {
        [
            "text": text,
            "origin.x": x,
            "origin.y": y,
            "size.x": 160.0,
            "size.y": 34.5,
            "fontFace": "TimesNewRomanPS-ItalicMT",
            "fontSize": 16.0,
            "fontColor": "Dark Gray",
            "fontWeight": 0,
            "layerID": "440A22B8-7DFF-4967-8231-E66AC87429DF",
            "layerVisible": 1,
            "kRecoverableDestination": 2,
        ]
    }

    static func makePDF(pages: Int) -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let ctx = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
        for _ in 0..<pages {
            ctx.beginPDFPage(nil)
            ctx.fill(CGRect(x: 100, y: 100, width: 50, height: 50))
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    /// A transparent PNG with a single stroke, like a forScore drawing layer.
    static func makeDrawingPNG() -> Data {
        let (w, h) = drawingSize
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setStrokeColor(CGColor(srgbRed: 0.1, green: 0.3, blue: 0.85, alpha: 1))
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: 100, y: 150, width: 30, height: 20))
        let data = NSMutableData()
        let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return data as Data
    }
}
