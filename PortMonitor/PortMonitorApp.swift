import SwiftUI

@main
struct PortMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window - menu bar only
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize status bar
        statusBarController = StatusBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
    }
}
