import CoreGraphics
import Foundation

public enum FourScoreError: Error, LocalizedError, Equatable {
    case notFound(String)
    case notPDF(String)
    case invalidContainer(String)
    case missingPDFData

    public var errorDescription: String? {
        switch self {
        case .notFound(let path): "Not found: \(path)"
        case .notPDF(let path): "Not a PDF: \(path)"
        case .invalidContainer(let reason): "Not a valid .4sc file: \(reason)"
        case .missingPDFData: "No 'pdfData' key found in plist"
        }
    }
}

/// A forScore `.4sc` interchange file: a gzip-compressed binary property list whose
/// `pdfData` key holds the PDF and whose other keys hold metadata and annotations.
///
/// Apart from `pdfData`, keys are of the form `<name>.pdf|<field>` (document metadata),
/// `<name>.pdf|<page>|<field>` (per-page data) or `<name>.pdf|<page>.png` (the page's
/// drawing layer). Page numbers are 1-based.
public struct FourScoreFile: @unchecked Sendable {
    public static let pdfDataKey = "pdfData"
    public static let fileExtension = "4sc"

    /// The decoded top-level dictionary. All unknown keys are preserved on write.
    public private(set) var plist: [String: Any]

    // MARK: Reading

    public init(data: Data) throws {
        let raw: Data
        do {
            raw = try GZip.decompress(data)
        } catch {
            throw FourScoreError.invalidContainer(error.localizedDescription)
        }
        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(from: raw, format: nil)
        } catch {
            throw FourScoreError.invalidContainer("could not decode property list")
        }
        guard let dict = object as? [String: Any] else {
            throw FourScoreError.invalidContainer("top-level object is not a dictionary")
        }
        guard dict[Self.pdfDataKey] is Data else { throw FourScoreError.missingPDFData }
        plist = dict
    }

    public init(contentsOf url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FourScoreError.notFound(url.relativePath)
        }
        try self.init(data: Data(contentsOf: url))
    }

    // MARK: Writing

    public func encoded() throws -> Data {
        let raw = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        return try GZip.compress(raw)
    }

    /// Overwrites `url` in place (truncate + write) so that the file's permissions,
    /// extended attributes and identity are preserved, as the original shell script did.
    public func write(inPlaceTo url: URL) throws {
        let data = try encoded()
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forUpdating: url)
            defer { try? handle.close() }
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
    }

    // MARK: PDF

    public var pdfData: Data {
        plist[Self.pdfDataKey] as? Data ?? Data()
    }

    /// Replaces the embedded PDF. Throws `notPDF` if `data` lacks a `%PDF-` header.
    public mutating func replacePDF(with data: Data, sourceName: String = "data") throws {
        guard Self.looksLikePDF(data) else { throw FourScoreError.notPDF(sourceName) }
        plist[Self.pdfDataKey] = data
    }

    public mutating func replacePDF(contentsOf url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FourScoreError.notFound(url.relativePath)
        }
        try replacePDF(with: Data(contentsOf: url), sourceName: url.relativePath)
    }

    public static func looksLikePDF(_ data: Data) -> Bool {
        data.prefix(5).elementsEqual("%PDF-".utf8)
    }

    public static func pageCount(ofPDF data: Data) -> Int? {
        guard let provider = CGDataProvider(data: data as CFData),
              let doc = CGPDFDocument(provider) else { return nil }
        return doc.numberOfPages
    }

    public var pageCount: Int? { Self.pageCount(ofPDF: pdfData) }

    // MARK: Keys

    /// The `<name>.pdf` prefix shared by all metadata keys (forScore's internal filename).
    public var documentName: String? {
        let prefixes = plist.keys.compactMap { key -> Substring? in
            guard key != Self.pdfDataKey, let bar = key.firstIndex(of: "|") else { return nil }
            return key[..<bar]
        }
        // Use the most common prefix in case of stray keys.
        let counts = Dictionary(prefixes.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }.map { String($0.key) }
    }

    /// Document-level metadata (`<name>.pdf|<field>`), e.g. title, composer, bpm.
    public var metadata: [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in plist {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            if parts.count == 2, !parts[1].hasSuffix(".png"), Int(parts[1]) == nil {
                result[String(parts[1])] = value
            }
        }
        return result
    }

    public var title: String? { metadata["title"] as? String }
}
