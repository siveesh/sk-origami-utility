import AppKit
import SwiftUI

@main
struct SKOrigamiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var workspace = ArchiveWorkspaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspace)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Archive...") {
                    workspace.presentOpenPanel()
                }
                .keyboardShortcut("o")

                Button("Create Archive...") {
                    workspace.presentCreateArchive()
                }
                .keyboardShortcut("n")

                Button("Add Folders for Disk Image...") {
                    workspace.presentFolderImagePanel()
                }
                .keyboardShortcut("i")
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var pendingOpenURLs: [URL] = []
    static var finderOpenHandler: (([URL]) -> Void)?
    static var incomingURLHandler: (([URL]) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApplication.shared.servicesProvider = self
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        if let finderOpenHandler = Self.finderOpenHandler {
            finderOpenHandler(urls)
        } else {
            Self.pendingOpenURLs.append(contentsOf: urls)
        }
    }

    @objc func handleFolders(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        var urls: [URL] = []

        if let paths = pasteboard.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String] {
            urls = paths.map { URL(fileURLWithPath: $0) }
        }

        if urls.isEmpty,
           let pastedURLs = pasteboard.readObjects(
               forClasses: [NSURL.self],
               options: [.urlReadingFileURLsOnly: true]
           ) as? [URL] {
            urls = pastedURLs
        }

        let folders = urls.filter(\.isExistingDirectory)
        guard !folders.isEmpty else { return }

        if let incomingURLHandler = Self.incomingURLHandler {
            incomingURLHandler(folders)
        } else {
            Self.pendingOpenURLs.append(contentsOf: folders)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        UserDefaults.standard.bool(forKey: PreferenceKeys.quitAfterLastWindowCloses)
    }
}
