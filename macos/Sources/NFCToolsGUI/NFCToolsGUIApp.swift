import AppKit
import SwiftUI

@main
@MainActor
struct NFCToolsGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(model)
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 840, height: 730)
        .windowResizability(.contentMinSize)
        .commands { AppCommands() }

        Window(t("html_dump_editor"), id: "dumpEditor") {
            DumpEditorView()
                .environmentObject(model)
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 500, height: 730)
        .windowResizability(.contentMinSize)

        Window(t("html_dump_comparator"), id: "dumpComparator") {
            DumpComparatorView()
                .environmentObject(model)
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 600, height: 730)
        .windowResizability(.contentMinSize)

        Window(t("html_dump_history"), id: "dumpHistory") {
            DumpHistoryView()
                .environmentObject(model)
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 480, height: 620)
        .windowResizability(.contentMinSize)

        Window(t("html_settings"), id: "settings") {
            SettingsView()
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 500, height: 380)
        .windowResizability(.contentMinSize)

        Window(t("html_about"), id: "about") {
            AboutView()
                .preferredColorScheme(preferredColorScheme)
        }
        .defaultSize(width: 580, height: 650)
        .windowResizability(.contentMinSize)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandGroup(replacing: .appInfo) {
            Button("\(t("html_about")) NFCToolsGUI") {
                openWindow(id: "about")
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set after the user confirms quitting from the custom close button so the
    /// standard applicationShouldTerminate callback does not ask twice.
    var approvedTermination = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if approvedTermination {
            return .terminateNow
        }
        guard AppModel.shared.confirmExitIfNeeded() else {
            return .terminateCancel
        }
        approvedTermination = true
        return .terminateNow
    }
}
