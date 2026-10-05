import FourScoreKit
import PDFKit
import SwiftUI

/// PDFKit view of the embedded PDF with forScore's annotations drawn on top.
struct AnnotatedPDFView: NSViewRepresentable {
    var model: DocumentModel

    func makeNSView(context: Context) -> PDFView {
        let view = DropPassthroughPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        model.pdfView = view
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        // Reading these registers observation so SwiftUI calls us again when they change.
        let revision = model.pdfRevision
        let show = model.showAnnotations
        let coordinator = context.coordinator

        if coordinator.revision != revision {
            coordinator.revision = revision
            coordinator.overlays = []
            let currentPage = view.currentPage.flatMap { view.document?.index(for: $0) }
            view.document = model.file.flatMap { PDFDocument(data: $0.pdfData) }
            if let index = currentPage, let page = view.document?.page(at: index) {
                view.go(to: page)
            }
            coordinator.overlays = makeOverlays(for: view.document)
            coordinator.shown = false
        }

        if coordinator.shown != show {
            coordinator.shown = show
            for overlay in coordinator.overlays {
                if show { overlay.page.addAnnotation(overlay.annotation) }
                else { overlay.page.removeAnnotation(overlay.annotation) }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var revision = -1
        var shown = false
        var overlays: [(page: PDFPage, annotation: PDFAnnotation)] = []
    }

    private func makeOverlays(for document: PDFDocument?) -> [(page: PDFPage, annotation: PDFAnnotation)] {
        guard let document, let file = model.file else { return [] }
        return file.pageAnnotations.values.compactMap { annotations in
            // forScore page numbers are 1-based.
            guard annotations.hasVisibleContent, let page = document.page(at: annotations.page - 1) else { return nil }
            return (page, ForScoreOverlayAnnotation(annotations, on: page))
        }
    }
}

/// A non-interactive annotation covering the whole page that draws forScore's layer.
final class ForScoreOverlayAnnotation: PDFAnnotation {
    let annotations: PageAnnotations

    init(_ annotations: PageAnnotations, on page: PDFPage) {
        self.annotations = annotations
        super.init(bounds: page.bounds(for: .cropBox), forType: .stamp, withProperties: nil)
        isReadOnly = true
        shouldPrint = true
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        AnnotationRenderer.draw(annotations, in: context, pageRect: bounds)
    }
}

/// PDFView registers for file drags itself; opt out so drops reach the SwiftUI drop target.
final class DropPassthroughPDFView: PDFView {
    override func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {}

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        unregisterDraggedTypes()
        documentView?.unregisterDraggedTypes()
    }
}
