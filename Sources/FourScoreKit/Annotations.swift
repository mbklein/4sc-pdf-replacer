import CoreGraphics
import Foundation

/// A text box placed on a page in forScore.
///
/// `origin` is normalized to the page (0...1, top-left origin, as in UIKit).
/// `size` and `fontSize` are in forScore's on-screen points; see
/// `FourScoreFile.textReferenceWidth` for how they're scaled to the page.
public struct TextAnnotation: Sendable, Equatable {
    public var text: String
    public var origin: CGPoint
    public var size: CGSize
    public var fontFace: String?
    public var fontSize: CGFloat
    public var fontColor: String?
    public var isVisible: Bool
    public var layerID: String?

    init?(_ dict: [String: Any]) {
        func number(_ key: String) -> CGFloat? {
            (dict[key] as? NSNumber).map { CGFloat($0.doubleValue) }
        }
        guard let x = number("origin.x"), let y = number("origin.y") else { return nil }
        text = dict["text"] as? String ?? ""
        origin = CGPoint(x: x, y: y)
        size = CGSize(width: number("size.x") ?? 160, height: number("size.y") ?? 30)
        fontFace = dict["fontFace"] as? String
        fontSize = number("fontSize") ?? 16
        fontColor = dict["fontColor"] as? String
        isVisible = (dict["layerVisible"] as? NSNumber)?.boolValue ?? true
        layerID = dict["layerID"] as? String
    }
}

/// Everything forScore stored for one page.
public struct PageAnnotations: @unchecked Sendable {
    /// 1-based page number.
    public var page: Int
    /// PNG of the freehand drawing layer, covering the whole page, transparent elsewhere.
    public var drawingPNG: Data?
    public var textAnnotations: [TextAnnotation]
    /// All other `<name>.pdf|<page>|<field>` values (e.g. `croppedLandscape`).
    public var otherFields: [String: Any]

    public var hasVisibleContent: Bool {
        drawingPNG != nil || textAnnotations.contains { $0.isVisible && !$0.text.isEmpty }
    }
}

extension FourScoreFile {
    /// forScore lays text out against a page displayed roughly 1024 points wide
    /// (the iPad's portrait width); text sizes are scaled from that to the PDF page.
    public static let textReferenceWidth: CGFloat = 1024

    /// Per-page annotations keyed by 1-based page number.
    public var pageAnnotations: [Int: PageAnnotations] {
        var pages: [Int: PageAnnotations] = [:]
        func entry(_ page: Int) -> PageAnnotations {
            pages[page] ?? PageAnnotations(page: page, drawingPNG: nil, textAnnotations: [], otherFields: [:])
        }
        for (key, value) in plist {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            if parts.count == 2, parts[1].hasSuffix(".png"), let page = Int(parts[1].dropLast(4)) {
                var e = entry(page)
                e.drawingPNG = value as? Data
                pages[page] = e
            } else if parts.count == 3, let page = Int(parts[1]) {
                var e = entry(page)
                if parts[2] == "textAnnotations", let list = value as? [[String: Any]] {
                    e.textAnnotations = list.compactMap(TextAnnotation.init)
                } else {
                    e.otherFields[String(parts[2])] = value
                }
                pages[page] = e
            }
        }
        return pages
    }

    /// Highest page number that carries a drawing or text annotation.
    public var lastAnnotatedPage: Int? {
        pageAnnotations.values.filter(\.hasVisibleContent).map(\.page).max()
    }
}
