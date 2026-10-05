# replace-4sc-pdf

Tools for swapping the PDF inside a [forScore](https://forscore.co) `.4sc` file while keeping its annotations and metadata.

## File format

forScore's data interchange format is a gzip-compressed Apple binary property list with a `.4sc` extension. The underlying PDF content is in a key called `pdfData`. Every other key is prefixed with forScore's internal filename (`<name>.pdf|…`):

| Key | Contents |
| --- | --- |
| `<name>.pdf|title`, `composer`, `keywords`, `labels`, `libraries`, `bpm`, `signature`, … | Document metadata (strings/numbers) |
| `<name>.pdf|<page>.png` | The page's freehand drawing layer: a transparent PNG (2732×3572 in the sample) stretched over the whole page |
| `<name>.pdf|<page>|textAnnotations` | Array of text boxes: `text`, `fontFace`, `fontSize`, `fontColor` (a color *name*, e.g. `Dark Gray`), `origin.x`/`origin.y` (normalized 0–1, top-left origin), `size.x`/`size.y` (points), `layerID`, `layerVisible` |
| `<name>.pdf|<page>|croppedLandscape` | Per-page display setting |

Page numbers are 1-based. Text sizes appear to be in points relative to a page displayed ~1024pt wide; the preview scales them on that assumption.

## Command line

```
replace4sc file.4sc new.pdf
```

The file is rewritten in place, preserving its permissions and attributes. Exits non-zero with a message if either file is missing or the new file isn't a PDF. It also warns (on stderr) if the new PDF's page count differs or if annotations exist on pages beyond the end of the new PDF.

## App

**4sc PDF Replacer** opens `.4sc` files and shows the embedded PDF with the drawings and text annotations overlaid (toggle with ⇧⌘A or the toolbar). Drag a PDF onto the window, or use File ▸ Replace PDF… (⇧⌘R), to swap it in. The preview updates immediately so you can check the annotations still line up; then save (⌘S). Undo works.

The app registers as an *alternate* handler for forScore's `com.forscore.4sc` type, so forScore stays the default app for these files. Use Open With, or drag files onto the app icon.

## Building

Requires Xcode 16+ / Swift 6 on macOS 14+.

```
scripts/build-app.sh              # build/4sc PDF Replacer.app and build/replace4sc
scripts/build-app.sh --universal  # arm64 + x86_64
swift test                        # FourScoreKit tests (self-contained; no fixture files)
```

### Versioning

The version lives in one place, `Sources/FourScoreKit/Version.swift`. `replace4sc --version` prints it, and `scripts/build-app.sh` stamps it into the app as `CFBundleShortVersionString`. The app's build number (`CFBundleVersion`) defaults to the git commit count; set `BUILD_NUMBER=<n>` to override it.

## Layout

- `Sources/FourScoreKit`: shared library. Reads and writes `.4sc` files (gzip + plist), replaces the PDF, parses annotations, and draws them with Core Graphics.
- `Sources/replace4sc`: the CLI.
- `Sources/FourScorePDFReplacer`: the AppKit/SwiftUI document app (PDFKit preview).
- `App/Info.plist`: the app bundle's Info.plist (document types).

## License

MIT. See [LICENSE](LICENSE).
