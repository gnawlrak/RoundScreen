import AppKit
import CoreGraphics
import Darwin
import Foundation
import RoundScreenCore

@MainActor
final class DisplayStateMonitor {
    var onUpdate: (([DisplayEvaluation]) -> Void)?

    private var pollTask: Task<Void, Never>?
    private var notificationObservers: [
        (center: NotificationCenter, token: NSObjectProtocol)
    ] = []
    private var settleTask: Task<Void, Never>?
    private var isRunning = false

    private let pollInterval = Duration.milliseconds(200)

    func start() {
        guard !isRunning else { return }
        isRunning = true
        subscribeToNotifications()
        refresh()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await Task.sleep(for: self.pollInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    func stop() {
        isRunning = false
        pollTask?.cancel()
        pollTask = nil
        settleTask?.cancel()
        settleTask = nil
        for observation in notificationObservers {
            observation.center.removeObserver(observation.token)
        }
        notificationObservers.removeAll()
        onUpdate?([])
    }

    func refresh() {
        guard isRunning, let primaryScreen = primaryScreen() else {
            onUpdate?([])
            return
        }

        let displays = NSScreen.screens.compactMap(\.displaySnapshot)
        let scan = WindowSnapshotProvider.scan(
            excludingPID: getpid(),
            primaryDisplayHeight: primaryScreen.frame.maxY
        )
        guard !scan.isMissionControlActive else {
            return
        }
        let nativeFullscreenFrames = NativeFullscreenProvider.frames(
            primaryDisplayHeight: primaryScreen.frame.maxY
        )
        let evaluations = DisplayStateResolver.evaluate(
            displays: displays,
            frontToBackWindows: scan.windows,
            nativeFullscreenFrames: nativeFullscreenFrames
        )
        onUpdate?(evaluations)
    }

    private func primaryScreen() -> NSScreen? {
        let mainDisplayID = CGMainDisplayID()
        return NSScreen.screens.first { $0.displayID == mainDisplayID }
            ?? NSScreen.screens.first
    }

    private func subscribeToNotifications() {
        observe(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.activeSpaceDidChangeNotification
        )
        observe(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.didActivateApplicationNotification
        )
        observe(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.screensDidWakeNotification
        )
        observe(
            center: .default,
            name: NSApplication.didChangeScreenParametersNotification
        )
    }

    private func observe(center: NotificationCenter, name: Notification.Name) {
        let token = center.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleSettledRefresh()
            }
        }
        notificationObservers.append((center, token))
    }

    private func scheduleSettledRefresh() {
        refresh()
        settleTask?.cancel()
        settleTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            self?.refresh()
        }
    }
}
