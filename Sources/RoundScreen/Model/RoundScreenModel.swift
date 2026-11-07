import Combine
import CoreGraphics
import Foundation
import RoundScreenCore

@MainActor
final class RoundScreenModel: ObservableObject {
    static let shared = RoundScreenModel()

    @Published private(set) var settings: RoundScreenSettings
    @Published private(set) var displayStatuses: [DisplayStatus] = []

    private let store: SettingsStore
    private let monitor = DisplayStateMonitor()
    private let sessionMonitor = SessionLockMonitor()
    private let overlays = OverlayCoordinator()
    private let settingsWindow = SettingsWindowController()
    private var lastEvaluations: [DisplayEvaluation] = []
    private var isStarted = false
    private var overlaysStarted = false
    private var unlockRefreshTask: Task<Void, Never>?

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        settings = store.load()
        monitor.onUpdate = { [weak self] evaluations in
            self?.apply(evaluations)
        }
    }

    var isEnabled: Bool {
        settings.isEnabled
    }

    var isCursorGuardActive: Bool {
        overlays.isCursorGuardActive
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        sessionMonitor.onLock = { [weak self] in
            self?.handleLock()
        }
        sessionMonitor.onUnlock = { [weak self] in
            self?.handleUnlock()
        }
        if settings.isEnabled {
            startOverlays()
            monitor.start()
        }
        sessionMonitor.start()
    }

    func stop() {
        unlockRefreshTask?.cancel()
        unlockRefreshTask = nil
        sessionMonitor.stop()
        monitor.stop()
        overlays.stop()
        overlaysStarted = false
        isStarted = false
    }

    func setEnabled(_ enabled: Bool) {
        guard settings.isEnabled != enabled else { return }
        settings.isEnabled = enabled
        store.save(settings)

        if enabled {
            if isStarted {
                startOverlays()
                if sessionMonitor.isLocked {
                    overlays.enterLocked(profile: settings.radiusProfile)
                }
                monitor.start()
            }
        } else {
            monitor.stop()
            lastEvaluations = []
            displayStatuses = []
            overlays.removeAll()
        }
    }

    func setNormalRadius(_ radius: Double) {
        settings.normalRadius = min(max(radius.rounded(), 0), 60)
        persistAndReapply()
    }

    func setMaximizedRadius(_ radius: Double) {
        settings.maximizedRadius = min(max(radius.rounded(), 0), 60)
        persistAndReapply()
    }

    func resetRadii() {
        settings.normalRadius = 20
        settings.maximizedRadius = 14
        persistAndReapply()
    }

    func refreshNow() {
        guard settings.isEnabled else { return }
        monitor.refresh()
    }

    func showSettings() {
        settingsWindow.show(model: self)
    }

    private func persistAndReapply() {
        store.save(settings)
        if sessionMonitor.isLocked {
            overlays.enterLocked(profile: settings.radiusProfile)
            return
        }
        apply(lastEvaluations)
    }

    private func apply(_ evaluations: [DisplayEvaluation]) {
        lastEvaluations = evaluations

        guard settings.isEnabled else {
            overlays.removeAll()
            if !displayStatuses.isEmpty {
                displayStatuses = []
            }
            return
        }

        let profile = settings.radiusProfile
        overlays.apply(
            evaluations: evaluations,
            profile: profile,
            enabled: true
        )

        let statuses = evaluations.map { evaluation in
            DisplayStatus(
                id: evaluation.display.id,
                name: evaluation.display.name,
                corners: evaluation.corners,
                radii: evaluation.corners.radii(using: profile)
            )
        }

        if statuses != displayStatuses {
            displayStatuses = statuses
        }
    }

    private func startOverlays() {
        guard !overlaysStarted else { return }
        overlays.start(profile: settings.radiusProfile)
        overlaysStarted = true
    }

    private func handleLock() {
        guard settings.isEnabled else { return }
        startOverlays()
        overlays.enterLocked(profile: settings.radiusProfile)
    }

    private func handleUnlock() {
        guard settings.isEnabled else { return }
        overlays.leaveLocked(profile: settings.radiusProfile)
        unlockRefreshTask?.cancel()
        unlockRefreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1150))
            } catch {
                return
            }
            self?.refreshNow()
        }
    }
}
