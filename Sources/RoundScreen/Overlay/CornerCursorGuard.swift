import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import OSLog
import RoundScreenCore

final class CornerCursorGuard: @unchecked Sendable {
    private struct Constraint {
        let displayID: String
        let frame: CGRect
        let radii: CornerRadiusSet
    }

    private struct ContactKey: Hashable {
        let displayID: String
        let corner: ScreenCorner
    }

    private let stateLock = NSLock()
    private var constraints: [Constraint] = []
    private var primaryHeight: CGFloat = 0
    private var triggeredContacts: Set<ContactKey> = []
    private var pendingContacts: [ContactKey: Task<Void, Never>] = [:]
    private static let hotCornerDwellDelay: Duration = .milliseconds(700)
    private static let hotCornerHoldTolerance: CGFloat = 10

    private var shouldRun = false
    private var didPromptForAccessibility = false
    private var didLogInstallationFailure = false
    private var warpEventSource: CGEventSource?
    private let logger = Logger(
        subsystem: "com.gnawlrak.RoundScreen",
        category: "CursorGuard"
    )
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTask: Task<Void, Never>?
    private var correctionTimer: DispatchSourceTimer?
    private let correctionQueue = DispatchQueue(
        label: "com.gnawlrak.RoundScreen.cursor-correction",
        qos: .userInteractive
    )

    var onCornerContact: (@MainActor (ScreenCorner, CGEventFlags) -> Void)?

    var isActive: Bool {
        guard shouldRun, let eventTap, CFMachPortIsValid(eventTap) else {
            return false
        }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() {
        guard !shouldRun else { return }
        shouldRun = true
        requestAccessibilityIfNeeded()
        configureWarpEventSource()
        if !installTapIfNeeded() {
            scheduleRetry()
        }
    }

    func stop() {
        shouldRun = false
        retryTask?.cancel()
        retryTask = nil

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        didLogInstallationFailure = false
        stopCorrectionTimer()
        clear()
    }

    func update(
        evaluations: [DisplayEvaluation],
        profile: CornerRadiusProfile,
        locked: Bool
    ) {
        let screens = NSScreen.screens
        let primaryHeight = screens.first {
            $0.displayID == CGMainDisplayID()
        }?.frame.maxY ?? screens.first?.frame.maxY ?? 0

        let constraints = screens.map { screen in
            let evaluation = evaluations.first {
                $0.display.id == screen.displayIdentifier
            }
            let radii = locked
                ? CornerRadiusSet(profile.normal)
                : evaluation?.corners.radii(using: profile) ?? .zero
            return Constraint(
                displayID: screen.displayIdentifier,
                frame: screen.frame,
                radii: radii
            )
        }

        stateLock.lock()
        self.constraints = constraints
        self.primaryHeight = primaryHeight
        stateLock.unlock()
    }

    func clear() {
        stateLock.lock()
        for task in pendingContacts.values {
            task.cancel()
        }
        pendingContacts.removeAll()
        constraints = []
        primaryHeight = 0
        triggeredContacts.removeAll()
        stateLock.unlock()
    }

    @discardableResult
    private func installTapIfNeeded() -> Bool {
        if eventTap != nil {
            return true
        }

        let tap = makeEventTap(at: .cghidEventTap)
            ?? makeEventTap(at: .cgSessionEventTap)
        guard let tap else {
            if !didLogInstallationFailure {
                let trusted = AXIsProcessTrusted()
                let listenAccess = CGPreflightListenEventAccess()
                let postAccess = CGPreflightPostEventAccess()
                logger.error(
                    "Mouse tap unavailable: accessibility=\(trusted, privacy: .public), listen=\(listenAccess, privacy: .public), post=\(postAccess, privacy: .public)"
                )
                didLogInstallationFailure = true
            }
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            tap,
            0
        ) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        didLogInstallationFailure = false
        let suppressionInterval = warpEventSource?.localEventsSuppressionInterval
            ?? -1
        logger.notice(
            "Mouse event tap installed and enabled; warp suppression=\(suppressionInterval, privacy: .public)s"
        )
        startCorrectionTimer()
        return true
    }

    private func configureWarpEventSource() {
        guard warpEventSource == nil else { return }

        guard let source = CGEventSource(stateID: .combinedSessionState)
            ?? CGEventSource(stateID: .hidSystemState)
        else {
            logger.error("Unable to create cursor warp event source")
            return
        }
        source.localEventsSuppressionInterval = 0
        warpEventSource = source
    }

    private func startCorrectionTimer() {
        guard correctionTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: correctionQueue)
        timer.schedule(
            deadline: .now() + .milliseconds(16),
            repeating: .milliseconds(16),
            leeway: .milliseconds(2)
        )
        timer.setEventHandler { [weak self] in
            self?.correctCursorIfNeeded()
        }
        correctionTimer = timer
        timer.resume()
    }

    private func stopCorrectionTimer() {
        correctionTimer?.cancel()
        correctionTimer = nil
    }

    private func correctCursorIfNeeded() {
        stateLock.lock()
        let constraints = self.constraints
        let primaryHeight = self.primaryHeight
        stateLock.unlock()

        guard primaryHeight > 0, !constraints.isEmpty else { return }
        guard let location = CGEvent(source: nil)?.location else { return }
        let point = CGPoint(
            x: location.x,
            y: primaryHeight - location.y
        )
        clearExpiredContacts(at: point, constraints: constraints)

        for constraint in constraints where Self.contains(point, in: constraint.frame) {
            for corner in ScreenCorner.allCases {
                guard let clamped = CornerCursorGeometry.clampedPoint(
                    for: point,
                    displayFrame: constraint.frame,
                    corner: corner,
                    radius: constraint.radii[corner]
                ) else {
                    continue
                }

                let target = CGPoint(
                    x: clamped.x,
                    y: primaryHeight - clamped.y
                )
                if hypot(target.x - location.x, target.y - location.y) > 0.1 {
                    CGWarpMouseCursorPosition(target)
                }
                beginContactIfNeeded(
                    displayID: constraint.displayID,
                    corner: corner,
                    flags: CGEvent(source: nil)?.flags ?? []
                )
                return
            }
        }
    }

    private func makeEventTap(
        at location: CGEventTapLocation
    ) -> CFMachPort? {
        let eventMask = [
            CGEventType.mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .leftMouseUp,
            .rightMouseUp,
            .otherMouseUp,
        ].reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << CGEventMask(type.rawValue))
        }

        return CGEvent.tapCreate(
            tap: location,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            while let self, self.shouldRun, self.eventTap == nil {
                try? await Task.sleep(for: .seconds(2))
                guard self.shouldRun else { return }
                if self.installTapIfNeeded() {
                    return
                }
            }
        }
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted(), !didPromptForAccessibility else { return }
        didPromptForAccessibility = true
        _ = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )
    }

    private func reenableTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        stateLock.lock()
        let constraints = self.constraints
        let primaryHeight = self.primaryHeight
        stateLock.unlock()

        guard primaryHeight > 0, !constraints.isEmpty else {
            return Unmanaged.passUnretained(event)
        }

        let location = event.location
        let point = CGPoint(
            x: location.x,
            y: primaryHeight - location.y
        )
        let eventFlags = event.flags
        clearExpiredContacts(at: point, constraints: constraints)

        for constraint in constraints where Self.contains(point, in: constraint.frame) {
            for corner in ScreenCorner.allCases {
                guard let clamped = CornerCursorGeometry.clampedPoint(
                    for: point,
                    displayFrame: constraint.frame,
                    corner: corner,
                    radius: constraint.radii[corner]
                ) else {
                    continue
                }
                let target = CGPoint(
                    x: clamped.x,
                    y: primaryHeight - clamped.y
                )
                CGWarpMouseCursorPosition(target)
                event.location = target
                beginContactIfNeeded(
                    displayID: constraint.displayID,
                    corner: corner,
                    flags: eventFlags
                )
                return Unmanaged.passUnretained(event)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func beginContactIfNeeded(
        displayID: String,
        corner: ScreenCorner,
        flags: CGEventFlags
    ) {
        let key = ContactKey(displayID: displayID, corner: corner)
        stateLock.lock()
        guard !triggeredContacts.contains(key),
              pendingContacts[key] == nil
        else {
            stateLock.unlock()
            return
        }
        let task = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.hotCornerDwellDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.finishPendingContact(
                key: key,
                corner: corner,
                flags: flags
            )
        }
        pendingContacts[key] = task
        stateLock.unlock()
    }

    private func finishPendingContact(
        key: ContactKey,
        corner: ScreenCorner,
        flags: CGEventFlags
    ) {
        stateLock.lock()
        guard pendingContacts.removeValue(forKey: key) != nil,
              let constraint = constraints.first(where: {
                  $0.displayID == key.displayID
              }),
              currentPointIsInsideHoldZone(
                  constraint: constraint,
                  corner: corner
              )
        else {
            stateLock.unlock()
            return
        }
        triggeredContacts.insert(key)
        stateLock.unlock()
        notifyCornerContact(corner, flags: flags)
    }

    private func clearExpiredContacts(
        at point: CGPoint,
        constraints: [Constraint]
    ) {
        let constraintsByDisplay = Dictionary(
            uniqueKeysWithValues: constraints.map { ($0.displayID, $0) }
        )

        stateLock.lock()
        for key in Array(pendingContacts.keys) {
            guard let constraint = constraintsByDisplay[key.displayID],
                  isInsideHoldZone(
                      point: point,
                      constraint: constraint,
                      corner: key.corner
                  )
            else {
                pendingContacts.removeValue(forKey: key)?.cancel()
                continue
            }
        }
        triggeredContacts = triggeredContacts.filter { key in
            guard let constraint = constraintsByDisplay[key.displayID] else {
                return false
            }
            return isInsideHoldZone(
                point: point,
                constraint: constraint,
                corner: key.corner
            )
        }
        stateLock.unlock()
    }

    private func currentPointIsInsideHoldZone(
        constraint: Constraint,
        corner: ScreenCorner
    ) -> Bool {
        guard primaryHeight > 0,
              let location = CGEvent(source: nil)?.location
        else {
            return false
        }
        let point = CGPoint(
            x: location.x,
            y: primaryHeight - location.y
        )
        return isInsideHoldZone(
            point: point,
            constraint: constraint,
            corner: corner
        )
    }

    private func isInsideHoldZone(
        point: CGPoint,
        constraint: Constraint,
        corner: ScreenCorner
    ) -> Bool {
        guard let distance = CornerCursorGeometry.distanceToInnerCurve(
            for: point,
            displayFrame: constraint.frame,
            corner: corner,
            radius: constraint.radii[corner]
        ) else {
            return false
        }
        return distance <= Self.hotCornerHoldTolerance
    }

    private func notifyCornerContact(
        _ corner: ScreenCorner,
        flags: CGEventFlags
    ) {
        guard onCornerContact != nil else { return }
        Task { @MainActor [weak self] in
            self?.onCornerContact?(corner, flags)
        }
    }

    private static func contains(_ point: CGPoint, in rect: CGRect) -> Bool {
        point.x >= rect.minX
            && point.x <= rect.maxX
            && point.y >= rect.minY
            && point.y <= rect.maxY
    }

    private static let eventTapCallback: CGEventTapCallBack = {
        _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }
        let guardObject = Unmanaged<CornerCursorGuard>
            .fromOpaque(userInfo)
            .takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            guardObject.reenableTap()
            return Unmanaged.passUnretained(event)
        }
        return guardObject.handle(event: event)
    }
}
