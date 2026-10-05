import CoreGraphics
import Foundation
import Testing
@testable import FourScoreKit

@Test func gzipRoundTrip() throws {
    let input = Data((0..<200_000).map { UInt8($0 % 251) })
    let compressed = try GZip.compress(input)
    #expect(GZip.isGzip(compressed))
    #expect(try GZip.decompress(compressed) == input)
    #expect(try GZip.decompress(GZip.compress(Data())) == Data())
}

@Test func readsFile() throws {
    let file = try Fixture.file()
    #expect(FourScoreFile.looksLikePDF(file.pdfData))
    #expect(file.pageCount == Fixture.pageCount)
    #expect(file.documentName == Fixture.name)
    #expect(file.title == "Test Score")
    #expect(file.metadata["signature"] as? String == "4/4")
    #expect(file.metadata["bpm"] as? Int == 80)
    // Per-page fields and drawing layers aren't document metadata.
    #expect(file.metadata.keys.allSatisfy { !$0.contains("|") && !$0.hasSuffix(".png") })
}

@Test func parsesAnnotations() throws {
    let file = try Fixture.file()
    let pages = file.pageAnnotations
    #expect(pages.values.filter { $0.drawingPNG != nil }.map(\.page).sorted() == Fixture.drawingPages)
    let page3 = try #require(pages[3])
    #expect(page3.textAnnotations.map(\.text) == ["crescendo"])
    #expect(page3.textAnnotations[0].fontFace == "TimesNewRomanPS-ItalicMT")
    #expect(page3.textAnnotations[0].origin.x == 0.5673828125)
    #expect(page3.otherFields["croppedLandscape"] as? Int == 0)
    // An empty text box doesn't count as visible content.
    #expect(pages[1]?.hasVisibleContent == false)
    #expect(file.lastAnnotatedPage == 3)
    #expect(AnnotationRenderer.decodeImage(try #require(page3.drawingPNG))?.width == Fixture.drawingSize.width)
}

@Test func rendersAnnotations() throws {
    let annotations = try #require(Fixture.file().pageAnnotations[3])
    let ctx = try #require(CGContext(data: nil, width: 612, height: 792, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    AnnotationRenderer.draw(annotations, in: ctx, pageRect: CGRect(x: 0, y: 0, width: 612, height: 792))
    let pixels = try #require(ctx.data).bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * 792)
    let opaque = stride(from: 3, to: ctx.bytesPerRow * 792, by: 4).filter { pixels[$0] > 0 }.count
    #expect(opaque > 0)
}

@Test func roundTripPreservesEverything() throws {
    let original = try Fixture.file()
    let reread = try FourScoreFile(data: original.encoded())
    #expect(NSDictionary(dictionary: original.plist).isEqual(to: reread.plist))
}

@Test func replacePDFKeepsOtherKeys() throws {
    var file = try Fixture.file()
    let before = file.plist
    let report = try file.replacePDFReporting(with: Fixture.makePDF(pages: Fixture.pageCount))
    #expect(report.warnings.isEmpty)
    #expect(file.pageCount == Fixture.pageCount)
    #expect(Set(file.plist.keys) == Set(before.keys))
    for key in before.keys where key != FourScoreFile.pdfDataKey {
        #expect((file.plist[key] as AnyObject).isEqual(before[key]))
    }
}

@Test func reportsPageMismatch() throws {
    var file = try Fixture.file()
    let report = try file.replacePDFReporting(with: Fixture.makePDF(pages: 2))
    #expect(report == ReplacementReport(oldPageCount: Fixture.pageCount, newPageCount: 2, lastAnnotatedPage: 3))
    #expect(report.warnings.count == 2)
}

@Test func rejectsNonPDF() throws {
    var file = try Fixture.file()
    #expect(throws: FourScoreError.notPDF("x.txt")) {
        try file.replacePDF(with: Data("hello".utf8), sourceName: "x.txt")
    }
}

@Test func rejectsNonFourScore() {
    #expect(throws: FourScoreError.self) { try FourScoreFile(data: Data("%PDF-1.4".utf8)) }
    let noPDF = try! GZip.compress(PropertyListSerialization.data(fromPropertyList: ["a": 1], format: .binary, options: 0))
    #expect(throws: FourScoreError.missingPDFData) { try FourScoreFile(data: noPDF) }
}

@Test func replaceInPlacePreservesPermissions() throws {
    let target = try Fixture.writeTemporary()
    try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
    let inodeBefore = try FileManager.default.attributesOfItem(atPath: target.path)[.systemFileNumber] as? Int
    let pdfURL = target.deletingLastPathComponent().appendingPathComponent("new.pdf")
    let pdf = Fixture.makePDF(pages: Fixture.pageCount)
    try pdf.write(to: pdfURL)

    try FourScoreFile.replacePDF(in: target, with: pdfURL)

    let attrs = try FileManager.default.attributesOfItem(atPath: target.path)
    #expect(attrs[.posixPermissions] as? Int == 0o640)
    #expect(attrs[.systemFileNumber] as? Int == inodeBefore)
    #expect(try FourScoreFile(contentsOf: target).pdfData == pdf)
}

@Test func replaceErrorsMatchScript() throws {
    let target = try Fixture.writeTemporary()
    let missing = URL(fileURLWithPath: "/nonexistent/file.4sc")
    #expect(throws: FourScoreError.notFound(missing.path)) {
        try FourScoreFile.replacePDF(in: missing, with: target)
    }
    #expect(throws: FourScoreError.notPDF(target.path)) {
        try FourScoreFile.replacePDF(in: target, with: target)
    }
}

@Test func versionIsSemantic() {
    // scripts/build-app.sh copies this into the app bundle, so keep it MAJOR.MINOR.PATCH.
    #expect(FourScoreVersion.string.wholeMatch(of: /\d+\.\d+\.\d+/) != nil)
}
