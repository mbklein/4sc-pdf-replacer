import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// Draws forScore annotations with Core Graphics, so the app (and anything else) can
/// overlay them on a rendered PDF page.
public enum AnnotationRenderer {
    /// Draws `annotations` over `pageRect`, which is in a bottom-left-origin
    /// coordinate space (PDF user space), as PDFKit/CGPDFPage drawing uses.
    public static func draw(_ annotations: PageAnnotations, in context: CGContext, pageRect: CGRect) {
        context.saveGState()
        defer { context.restoreGState() }

        if let png = annotations.drawingPNG, let image = decodeImage(png) {
            context.interpolationQuality = .high
            context.draw(image, in: pageRect)
        }

        let scale = pageRect.width / FourScoreFile.textReferenceWidth
        for text in annotations.textAnnotations where text.isVisible && !text.text.isEmpty {
            draw(text, in: context, pageRect: pageRect, scale: scale)
        }
    }

    public static func decodeImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func draw(_ annotation: TextAnnotation, in context: CGContext, pageRect: CGRect, scale: CGFloat) {
        let fontSize = annotation.fontSize * scale
        let font = CTFontCreateWithName((annotation.fontFace ?? "Helvetica") as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(named: annotation.fontColor),
        ]
        let string = NSAttributedString(string: annotation.text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(string)

        // Normalized top-left origin -> PDF space; let the box grow to fit its text.
        let width = annotation.size.width * scale
        let fitted = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: 0), nil,
            CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        let height = max(annotation.size.height * scale, fitted.height)
        let top = pageRect.maxY - annotation.origin.y * pageRect.height
        let rect = CGRect(x: pageRect.minX + annotation.origin.x * pageRect.width,
                          y: top - height, width: width, height: height)

        // Inset slightly to mimic forScore's text box padding.
        let inset = 4 * scale
        let path = CGPath(rect: rect.insetBy(dx: inset, dy: inset), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
    }

    /// forScore stores colors by name.
    static func color(named name: String?) -> CGColor {
        let rgb: (CGFloat, CGFloat, CGFloat) = switch name?.lowercased() {
        case "black": (0, 0, 0)
        case "white": (1, 1, 1)
        case "gray", "grey": (0.5, 0.5, 0.5)
        case "light gray", "light grey": (0.75, 0.75, 0.75)
        case "red": (0.85, 0.1, 0.1)
        case "orange": (0.95, 0.5, 0.1)
        case "yellow": (0.95, 0.8, 0.1)
        case "green": (0.15, 0.6, 0.2)
        case "blue": (0.1, 0.3, 0.85)
        case "purple": (0.5, 0.2, 0.7)
        case "brown": (0.5, 0.3, 0.15)
        default: (0.25, 0.25, 0.25) // "Dark Gray" and anything unrecognized
        }
        return CGColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
}
