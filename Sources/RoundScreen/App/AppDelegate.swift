import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        RoundScreenModel.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        RoundScreenModel.shared.stop()
    }
}
