import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Instantiate our controller before anything else touches NSDocumentController.shared.
        _ = DocumentController()
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate()
        // If we weren't launched by opening a file, prompt for one.
        DispatchQueue.main.async {
            if NSDocumentController.shared.documents.isEmpty {
                NSDocumentController.shared.openDocument(nil)
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSDocumentController.shared.openDocument(nil) }
        return false
    }
}

/// A `.4sc` file can't be created from scratch, so there is no "New" document.
final class DocumentController: NSDocumentController {
    override func newDocument(_ sender: Any?) {
        openDocument(sender)
    }
}

@MainActor
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "4sc PDF Replacer"

        main.addSubmenu("") { m in
            m.addItem("About \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
            m.addItem(.separator())
            let services = NSMenu()
            m.addItem(withTitle: "Services", action: nil, keyEquivalent: "").submenu = services
            NSApp.servicesMenu = services
            m.addItem(.separator())
            m.addItem("Hide \(appName)", #selector(NSApplication.hide(_:)), "h")
            m.addItem("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option])
            m.addItem("Show All", #selector(NSApplication.unhideAllApplications(_:)))
            m.addItem(.separator())
            m.addItem("Quit \(appName)", #selector(NSApplication.terminate(_:)), "q")
        }

        main.addSubmenu("File") { m in
            m.addItem("Open…", #selector(NSDocumentController.openDocument(_:)), "o")
            let recent = NSMenu(title: "Open Recent")
            // NSDocumentController populates the menu that contains this item.
            recent.addItem("Clear Menu", #selector(NSDocumentController.clearRecentDocuments(_:)))
            m.addItem(withTitle: "Open Recent", action: nil, keyEquivalent: "").submenu = recent
            m.addItem(.separator())
            m.addItem("Replace PDF…", #selector(FourScoreDocument.chooseReplacementPDF(_:)), "r", [.command, .shift])
            m.addItem(.separator())
            m.addItem("Close", #selector(NSWindow.performClose(_:)), "w")
            m.addItem("Save", #selector(NSDocument.save(_:)), "s")
            m.addItem("Save As…", #selector(NSDocument.saveAs(_:)), "s", [.command, .shift])
            m.addItem("Revert to Saved", #selector(NSDocument.revertToSaved(_:)))
        }

        main.addSubmenu("Edit") { m in
            m.addItem("Undo", Selector(("undo:")), "z")
            m.addItem("Redo", Selector(("redo:")), "z", [.command, .shift])
            m.addItem(.separator())
            m.addItem("Copy", #selector(NSText.copy(_:)), "c")
            m.addItem("Select All", #selector(NSText.selectAll(_:)), "a")
        }

        main.addSubmenu("View") { m in
            m.addItem("Show Annotations", #selector(FourScoreDocument.toggleAnnotations(_:)), "a", [.command, .shift])
            m.addItem(.separator())
            m.addItem("Actual Size", #selector(FourScoreDocument.zoomActualSize(_:)), "0")
            m.addItem("Zoom In", #selector(FourScoreDocument.zoomIn(_:)), "+")
            m.addItem("Zoom Out", #selector(FourScoreDocument.zoomOut(_:)), "-")
            m.addItem(.separator())
            m.addItem("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])
        }

        main.addSubmenu("Window") { m in
            m.addItem("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
            m.addItem("Zoom", #selector(NSWindow.performZoom(_:)))
            m.addItem(.separator())
            m.addItem("Bring All to Front", #selector(NSApplication.arrangeInFront(_:)))
            NSApp.windowsMenu = m
        }

        return main
    }
}

private extension NSMenu {
    func addSubmenu(_ title: String, _ build: (NSMenu) -> Void) {
        let menu = NSMenu(title: title)
        build(menu)
        addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
    }

    @discardableResult
    func addItem(_ title: String, _ action: Selector?, _ key: String = "",
                 _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = addItem(withTitle: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}
