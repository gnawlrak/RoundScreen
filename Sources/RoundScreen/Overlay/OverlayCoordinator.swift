import AppKit
import CoreGraphics
import Foundation
import RoundScreenCore

@MainActor
final class OverlayCoordinator {
    private var desktopWindows: [String: CornerOverlayWindow] = [:]
    private var lockWindows: [String: CornerOverlayWindow] = [:]
    private let persistentSpace = PersistentSpace()
    private let cursorGuard = CornerCursorGuard()

    private var profile: CornerRadiusProfile = .standard
    private var evaluations: [DisplayEvaluation] = []
    private var transitionEvaluations: [DisplayEvaluation] = []
    private var enabled = false
    private var isLocked = false
    private var isHoldingAfterUnlock = false
    private var unlockTask: Task<Void, Never>?
    private var notificationTasks: [Task<Void, Never>] = []

    var isCursorGuardActive: Bool {
        cursorGuard.isActive
    }

    func start(profile: CornerRadiusProfile) {
        self.profile = profile
        cursorGuard.onCornerContact = { corner, flags in
            HotCornerActionService.shared.performIfConfigured(
                corner: corner,
                eventFlags: flags
            )
        }
        cursorGuard.start()
        prepareLockWindows(profile: profile)
        observeEnvironment()
    }

    func stop() {
        cursorGuard.stop()
        unlockTask?.cancel()
        unlockTask = nil
        for task in notificationTasks {
            task.cancel()
        }
        notificationTasks.removeAll()
        removeAll()
    }

    func apply(
        evaluations: [DisplayEvaluation],
        profile: CornerRadiusProfile,
        enabled: Bool
    ) {
        self.evaluations = evaluations
        self.profile = profile
        self.enabled = enabled

        guard enabled else {
            cursorGuard.stop()
            removeAllWindows()
            return
        }
        cursorGuard.start()
        guard !isLocked, !isHoldingAfterUnlock else { return }
        syncDesktopWindows(evaluations, animated: true)
    }

    func enterLocked(profile: CornerRadiusProfile) {
        self.profile = profile
        unlockTask?.cancel()
        unlockTask = nil
        if !isLocked {
            transitionEvaluations = evaluations
        }
        isHoldingAfterUnlock = false
        isLocked = true

        hideDesktopWindows()
        prepareLockWindows(profile: profile)
        for window in lockWindows.values {
            window.setRadii(CornerRadiusSet(profile.normal), animated: false)
            window.setVisible(true, animated: false)
        }
        cursorGuard.update(
            evaluations: evaluations,
            profile: profile,
            locked: true
        )
    }

    func leaveLocked(profile: CornerRadiusProfile) {
        self.profile = profile
        isLocked = false
        isHoldingAfterUnlock = true

        for (id, window) in lockWindows {
            window.orderFrontRegardless()
            let target = transitionEvaluations.first { $0.display.id == id }
            if target?.corners.isFullscreen == true {
                window.setRadii(.zero, animated: true)
            } else {
                let radii = target?.corners.radii(using: profile)
                    ?? CornerRadiusSet(profile.normal)
                window.setRadii(radii, animated: true)
            }
        }
        cursorGuard.update(
            evaluations: transitionEvaluations,
            profile: profile,
            locked: false
        )

        unlockTask?.cancel()
        unlockTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard let self, !self.isLocked else { return }
            self.isHoldingAfterUnlock = false
            guard self.enabled else {
                self.hideLockWindows()
                self.transitionEvaluations = []
                return
            }
            self.syncDesktopWindows(self.transitionEvaluations, animated: false)
            self.reassertDesktopWindows()
            self.fadeOutLockWindows()
            self.transitionEvaluations = []
        }
    }

    func reassertDesktopWindows() {
        guard enabled, !isLocked, !isHoldingAfterUnlock else { return }
        for (id, window) in desktopWindows {
            guard evaluations.contains(where: { $0.display.id == id }) else {
                continue
            }
            persistentSpace.attach(window)
            window.orderFrontRegardless()
        }
    }

    func prepareLockWindows(profile: CornerRadiusProfile) {
        let screens = NSScreen.screens
        let activeIDs = Set(screens.map(\.displayIdentifier))

        let staleIDs = lockWindows.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs {
            lockWindows[id]?.setVisible(false, animated: false)
            lockWindows[id]?.contentView = nil
            lockWindows[id]?.close()
            lockWindows[id] = nil
        }

        for screen in screens {
            let id = screen.displayIdentifier
            let window = lockWindows[id] ?? makeLockWindow(frame: screen.frame)
            lockWindows[id] = window
            window.updateFrame(screen.frame)
            window.setRadii(CornerRadiusSet(profile.normal), animated: false)
            window.delegateToSkyLightIfNeeded()
            if isLocked {
                window.setVisible(true, animated: false)
            }
        }
    }

    func removeAll() {
        unlockTask?.cancel()
        unlockTask = nil
        isLocked = false
        isHoldingAfterUnlock = false
        evaluations = []
        transitionEvaluations = []
        removeAllWindows()
    }

    private func observeEnvironment() {
        observe(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.activeSpaceDidChangeNotification
        ) { [weak self] in
            self?.reassertDesktopWindows()
        }
        observe(
            center: .default,
            name: NSApplication.didChangeScreenParametersNotification
        ) { [weak self] in
            self?.refreshDisplays()
        }
        observe(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.screensDidWakeNotification
        ) { [weak self] in
            self?.refreshDisplays()
        }
    }

    private func observe(
        center: NotificationCenter,
        name: Notification.Name,
        action: @escaping () -> Void
    ) {
        let task = Task { @MainActor in
            for await _ in center.notifications(named: name) {
                guard !Task.isCancelled else { return }
                action()
            }
        }
        notificationTasks.append(task)
    }

    private func refreshDisplays() {
        prepareLockWindows(profile: profile)
        guard !isLocked, !isHoldingAfterUnlock, enabled else { return }
        syncDesktopWindows(evaluations, animated: false)
        reassertDesktopWindows()
    }

    private func syncDesktopWindows(_ evaluations: [DisplayEvaluation], animated: Bool) {
        let activeIDs = Set(evaluations.map(\.display.id))
        let staleIDs = desktopWindows.keys.filter { !activeIDs.contains($0) }
        for id in staleIDs {
            if let window = desktopWindows[id] {
                window.setVisible(false, animated: false)
                persistentSpace.detach(window)
                window.contentView = nil
                window.close()
            }
            desktopWindows[id] = nil
        }

        for evaluation in evaluations {
            let window: CornerOverlayWindow
            let isNew: Bool
            if let existing = desktopWindows[evaluation.display.id] {
                window = existing
                isNew = false
            } else {
                window = makeDesktopWindow(frame: evaluation.display.frame)
                desktopWindows[evaluation.display.id] = window
                isNew = true
            }

            window.updateFrame(evaluation.display.frame)
            let radii = evaluation.corners.radii(using: profile)
            window.setRadii(radii, animated: animated)
            if isNew {
                persistentSpace.attach(window)
            }

            window.setVisible(true, animated: animated)
        }
        cursorGuard.update(
            evaluations: evaluations,
            profile: profile,
            locked: false
        )
    }

    private func hideDesktopWindows() {
        for window in desktopWindows.values {
            window.setVisible(false, animated: false)
        }
    }

    private func hideLockWindows() {
        for window in lockWindows.values {
            window.setVisible(false, animated: false)
        }
    }

    private func fadeOutLockWindows() {
        for window in lockWindows.values {
            window.setVisible(false, animated: true)
        }
    }

    private func removeAllWindows() {
        for window in desktopWindows.values {
            window.setVisible(false, animated: false)
            persistentSpace.detach(window)
            window.contentView = nil
            window.close()
        }
        desktopWindows.removeAll()

        for window in lockWindows.values {
            window.setVisible(false, animated: false)
            window.contentView = nil
            window.close()
        }
        lockWindows.removeAll()
        cursorGuard.clear()
    }

    private func makeDesktopWindow(frame: CGRect) -> CornerOverlayWindow {
        CornerOverlayWindow(frame: frame, level: .screenSaver)
    }

    private func makeLockWindow(frame: CGRect) -> CornerOverlayWindow {
        CornerOverlayWindow(
            frame: frame,
            level: NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        )
    }
}
