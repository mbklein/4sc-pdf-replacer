import Foundation

/// Summary of a PDF replacement, shared by the CLI and the app for reporting.
public struct ReplacementReport: Sendable, Equatable {
    public var oldPageCount: Int?
    public var newPageCount: Int?
    public var lastAnnotatedPage: Int?

    /// Human-readable warnings about the new PDF not lining up with existing annotations.
    public var warnings: [String] {
        var result: [String] = []
        if newPageCount == nil {
            result.append("The new PDF could not be parsed; forScore may not be able to open it.")
        }
        if let new = newPageCount, let old = oldPageCount, new != old {
            result.append("Page count changed from \(old) to \(new).")
        }
        if let new = newPageCount, let last = lastAnnotatedPage, last > new {
            result.append("Annotations exist on page \(last), but the new PDF has only \(new) page\(new == 1 ? "" : "s").")
        }
        return result
    }
}

extension FourScoreFile {
    /// Replaces the embedded PDF and reports how the change lines up with existing annotations.
    @discardableResult
    public mutating func replacePDFReporting(with data: Data, sourceName: String = "data") throws -> ReplacementReport {
        let old = pageCount
        try replacePDF(with: data, sourceName: sourceName)
        return ReplacementReport(oldPageCount: old, newPageCount: pageCount, lastAnnotatedPage: lastAnnotatedPage)
    }

    /// The whole shell-script workflow: load `fileURL`, swap in `pdfURL`, and write back in place.
    @discardableResult
    public static func replacePDF(in fileURL: URL, with pdfURL: URL) throws -> ReplacementReport {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw FourScoreError.notFound(fileURL.relativePath) }
        guard FileManager.default.fileExists(atPath: pdfURL.path) else { throw FourScoreError.notFound(pdfURL.relativePath) }
        let pdf = try Data(contentsOf: pdfURL)
        guard looksLikePDF(pdf) else { throw FourScoreError.notPDF(pdfURL.relativePath) }
        var file = try FourScoreFile(contentsOf: fileURL)
        let report = try file.replacePDFReporting(with: pdf, sourceName: pdfURL.relativePath)
        try file.write(inPlaceTo: fileURL)
        return report
    }
}
