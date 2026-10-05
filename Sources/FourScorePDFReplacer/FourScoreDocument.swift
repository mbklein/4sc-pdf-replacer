import AppKit
import FourScoreKit
import Observation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// forScore's own type (also declared as imported in Info.plist for Macs without forScore).
    static let fourScore = UTType(importedAs: "com.forscore.4sc")
}

/// State shared between the document and its SwiftUI view.
@MainActor @Observable
final class DocumentModel {
    var file: FourScoreFile?
    var showAnnotations = true
    var lastReport: ReplacementReport?
    var lastReplacementName: String?
    var errorMessage: String?
    /// Bumped whenever the embedded PDF changes, so the view rebuilds its PDFDocument.
    private(set) var pdfRevision = 0

    @ObservationIgnored weak var pdfView: PDFView?

    func pdfChanged() { pdfRevision += 1 }
}

@objc(FourScoreDocument)
final class FourScoreDocument: NSDocument {
    let model = MainActor.assumeIsolated { DocumentModel() }

    override class var autosavesInPlace: Bool { false }

    override nonisolated func read(from data: Data, ofType typeName: String) throws {
        let file = try FourScoreFile(data: data)
        MainActor.assumeIsolated {
            model.file = file
            model.lastReport = nil
            model.pdfChanged()
        }
    }

    override nonisolated func data(ofType typeName: String) throws -> Data {
        let file = MainActor.assumeIsolated { model.file }
        guard let file else { throw CocoaError(.fileWriteUnknown) }
        return try file.encoded()
    }

    override func makeWindowControllers() {
        let view = DocumentView(model: model) { [weak self] url in
            self?.replacePDF(from: url)
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 760, height: 900))
        window.minSize = NSSize(width: 420, height: 400)
        window.tabbingMode = .preferred
        let controller = NSWindowController(window: window)
        controller.shouldCascadeWindows = true
        addWindowController(controller)
        window.setFrameAutosaveName("FourScoreDocumentWindow")
        #if DEBUG
        debugSnapshotIfRequested()
        #endif
    }

    // MARK: Replacing the PDF

    func replacePDF(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            try replacePDF(with: data, sourceName: url.lastPathComponent)
        } catch {
            presentError(error)
        }
    }

    func replacePDF(with data: Data, sourceName: String) throws {
        guard var file = model.file else { return }
        let previous = file.pdfData
        let previousReport = model.lastReport
        let previousName = model.lastReplacementName
        let report = try file.replacePDFReporting(with: data, sourceName: sourceName)

        model.file = file
        model.lastReport = report
        model.lastReplacementName = sourceName
        model.pdfChanged()

        undoManager?.registerUndo(withTarget: self) { doc in
            MainActor.assumeIsolated {
                try? doc.replacePDF(with: previous, sourceName: "previous PDF")
                doc.model.lastReport = previousReport
                doc.model.lastReplacementName = previousName
            }
        }
        undoManager?.setActionName("Replace PDF")
    }

    @objc func chooseReplacementPDF(_ sender: Any?) {
        guard let window = windowControllers.first?.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a PDF to embed in this forScore file"
        panel.prompt = "Replace"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.replacePDF(from: url)
        }
    }

    // MARK: View commands

    @objc func toggleAnnotations(_ sender: Any?) {
        model.showAnnotations.toggle()
    }

    @objc func zoomIn(_ sender: Any?) { model.pdfView?.zoomIn(sender) }
    @objc func zoomOut(_ sender: Any?) { model.pdfView?.zoomOut(sender) }
    @objc func zoomActualSize(_ sender: Any?) {
        model.pdfView?.autoScales = false
        model.pdfView?.scaleFactor = 1
    }

    override func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleAnnotations(_:)) {
            item.state = model.showAnnotations ? .on : .off
        }
        return super.validateMenuItem(item)
    }
}

#if DEBUG
extension FourScoreDocument {
    /// Debug aid: with FSR_SNAPSHOT=/path/out.png set, writes the first window's contents
    /// to a PNG shortly after it opens (and FSR_REPLACE=/path/new.pdf replaces the PDF first).
    func debugSnapshotIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["FSR_SNAPSHOT"] else { return }
        if let pdf = env["FSR_REPLACE"] { replacePDF(from: URL(fileURLWithPath: pdf)) }
        if env["FSR_HIDE_ANNOTATIONS"] != nil { model.showAnnotations = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let view = self?.windowControllers.first?.window?.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
            // PDFView's tiled layers don't show up in cacheDisplay, so also dump a page
            // thumbnail (which includes annotations) from the live view.
            if let page = self?.model.pdfView?.document?.page(at: Int(env["FSR_PAGE"] ?? "2").map { $0 - 1 } ?? 1),
               let tiff = page.thumbnail(of: NSSize(width: 900, height: 1200), for: .cropBox).tiffRepresentation {
                try? NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])?
                    .write(to: URL(fileURLWithPath: out).deletingPathExtension().appendingPathExtension("page.png"))
            }
        }
    }
}
#endif
