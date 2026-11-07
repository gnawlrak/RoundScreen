import AppKit
import CoreGraphics
import Foundation

@MainActor
final class SessionLockMonitor: NSObject {
    var onLock: (() -> Void)?
    var onUnlock: (() -> Void)?

    private(set) var isLocked = false
    private var pollTask: Task<Void, Never>?
    private var lastUnlockEvent = ContinuousClock.now - .seconds(10)

    override init() {
        super.init()
    }

    func start() {
        let distributedCenter = DistributedNotificationCenter.default()
        distributedCenter.addObserver(
            self,
            selector: #selector(screenLocked),
            name: .init("com.apple.screenIsLocked"),
            object: nil
        )
        distributedCenter.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: .init("com.apple.screenIsUnlocked"),
            object: nil
        )
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                self?.pollLockState()
            }
        }

        pollLockState()
    }

    func stop() {
        let distributedCenter = DistributedNotificationCenter.default()
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        distributedCenter.removeObserver(self)
        workspaceCenter.removeObserver(self)
        pollTask?.cancel()
        pollTask = nil
    }

    @objc nonisolated private func screenLocked() {
        Task { @MainActor [weak self] in
            self?.applyLockedState(true)
        }
    }

    @objc nonisolated private func screenUnlocked() {
        Task { @MainActor [weak self] in
            self?.applyLockedState(false)
        }
    }

    private func pollLockState() {
        let sessionLocked = Self.isSessionLocked()
        if sessionLocked {
            guard lastUnlockEvent.duration(to: .now) > .seconds(1.5) else { return }
            applyLockedState(true)
        } else {
            applyLockedState(false)
        }
    }

    private func applyLockedState(_ locked: Bool) {
        if !locked {
            lastUnlockEvent = .now
        }
        guard isLocked != locked else { return }
        isLocked = locked
        if locked {
            onLock?()
        } else {
            onUnlock?()
        }
    }

    private static func isSessionLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
