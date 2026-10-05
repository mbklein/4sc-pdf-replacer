import FourScoreKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentView: View {
    @Bindable var model: DocumentModel
    var onDropPDF: (URL) -> Void

    @State private var isTargeted = false
    @State private var bannerDismissed = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if let report = model.lastReport, !bannerDismissed {
                ReplacementBanner(report: report, sourceName: model.lastReplacementName) {
                    bannerDismissed = true
                }
            }
            ZStack {
                AnnotatedPDFView(model: model)
                if isTargeted { dropOverlay }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .onChange(of: model.pdfRevision) { bannerDismissed = false }
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $model.showAnnotations) {
                    Label("Annotations", systemImage: "pencil.tip.crop.circle")
                }
                .help("Show forScore annotations over the PDF")
                Button {
                    NSApp.sendAction(#selector(FourScoreDocument.chooseReplacementPDF(_:)), to: nil, from: nil)
                } label: {
                    Label("Replace PDF…", systemImage: "doc.badge.arrow.up")
                }
                .help("Choose a new PDF to embed (or drag one onto the window)")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.file?.title ?? model.file?.documentName ?? "Untitled")
                    .font(.headline)
                if let composer = model.file?.metadata["composer"] as? String {
                    Text(composer).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let file = model.file {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pageSummary(file)).font(.caption).foregroundStyle(.secondary)
                    Text("Drop a PDF to replace").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func pageSummary(_ file: FourScoreFile) -> String {
        let pages = file.pageCount.map { "\($0) page\($0 == 1 ? "" : "s")" } ?? "Unreadable PDF"
        let annotated = file.pageAnnotations.values.filter(\.hasVisibleContent).count
        return annotated > 0 ? "\(pages) · \(annotated) annotated" : pages
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.12)))
            .overlay {
                Label("Drop PDF to replace", systemImage: "doc.badge.arrow.up")
                    .font(.title2.weight(.semibold))
                    .padding()
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(12)
            .allowsHitTesting(false)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async {
                if url.pathExtension.lowercased() == FourScoreFile.fileExtension {
                    // Dropping another .4sc opens it rather than embedding it.
                    NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
                } else {
                    onDropPDF(url)
                }
            }
        }
        return true
    }
}

private struct ReplacementBanner: View {
    var report: ReplacementReport
    var sourceName: String?
    var dismiss: () -> Void

    var body: some View {
        let warnings = report.warnings
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: warnings.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(warnings.isEmpty ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Replaced PDF\(sourceName.map { " with \($0)" } ?? ""). Save to write the file.")
                    .font(.callout.weight(.medium))
                ForEach(warnings, id: \.self) { Text($0).font(.caption) }
            }
            Spacer()
            Button(action: dismiss) { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(warnings.isEmpty ? Color.green.opacity(0.12) : Color.orange.opacity(0.15))
    }
}
