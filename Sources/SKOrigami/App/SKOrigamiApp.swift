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
                    workspace.isShowingCreateSheet = true
                }
                .keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static var pendingOpenURLs: [URL] = []
    static var openHandler: (([URL]) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        if let openHandler = Self.openHandler {
            openHandler(urls)
        } else {
            Self.pendingOpenURLs.append(contentsOf: urls)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        UserDefaults.standard.bool(forKey: PreferenceKeys.quitAfterLastWindowCloses)
    }
}
