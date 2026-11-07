import AppKit
import CoreGraphics
import Foundation
import OSLog
import RoundScreenCore

@_silgen_name("CoreDockSendNotification")
private func CoreDockSendNotification(_ name: CFString, _ flags: Int32)

@MainActor
final class HotCornerActionService {
    static let shared = HotCornerActionService()

    private let logger = Logger(
        subsystem: "com.gnawlrak.RoundScreen",
        category: "HotCorner"
    )
    private var lastActionTimes: [HotCornerAction: Date] = [:]
    private let cooldown: TimeInterval = 0.45

    func performIfConfigured(
        corner: ScreenCorner,
        eventFlags: CGEventFlags
    ) {
        guard let binding = HotCornerPreferences.binding(for: corner),
              binding.matches(eventFlags: eventFlags)
        else {
            return
        }

        let now = Date()
        if let lastAction = lastActionTimes[binding.action],
           now.timeIntervalSince(lastAction) < cooldown
        {
            return
        }
        lastActionTimes[binding.action] = now

        logger.notice(
            "Hot corner \(corner.rawValue, privacy: .public) executing \(binding.action.displayName, privacy: .public)"
        )
        execute(binding.action)
    }

    private func execute(_ action: HotCornerAction) {
        switch action {
        case .missionControl:
            postDockNotification("com.apple.expose.awake")
        case .applicationWindows:
            postDockNotification("com.apple.expose.front.awake")
        case .showDesktop:
            postDockNotification("com.apple.showdesktop.awake")
        case .startScreenSaver:
            openScreenSaver()
        case .disableScreenSaver:
            terminateScreenSaver()
        case .launchpad:
            postDockNotification("com.apple.launchpad.toggle")
        case .notificationCenter:
            postDockNotification("com.apple.dock.notificationcenter")
        case .sleepDisplay:
            runProcess(
                executable: "/usr/bin/pmset",
                arguments: ["displaysleepnow"]
            )
        case .lockScreen:
            lockScreen()
        case .quickNote:
            postKey(keyCode: 12, flags: [.maskSecondaryFn])
        case .dashboard:
            logger.notice("Dashboard action is no longer available")
        }
    }

    private func postDockNotification(_ name: String) {
        CoreDockSendNotification(name as CFString, 0)
    }

    private func openScreenSaver() {
        runProcess(
            executable: "/usr/bin/open",
            arguments: [
                "-a",
                "/System/Library/CoreServices/ScreenSaverEngine.app",
            ]
        )
    }

    private func terminateScreenSaver() {
        runProcess(
            executable: "/usr/bin/killall",
            arguments: ["ScreenSaverEngine"]
        )
    }

    private func lockScreen() {
        postKey(
            keyCode: 12,
            flags: [.maskControl, .maskCommand]
        )
    }

    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: keyCode,
                  keyDown: true
              ),
              let keyUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: keyCode,
                  keyDown: false
              )
        else {
            logger.error("Unable to create hot corner keyboard event")
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func runProcess(
        executable: String,
        arguments: [String]
    ) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error(
                "Hot corner process failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
