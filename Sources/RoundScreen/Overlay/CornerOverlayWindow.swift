import AppKit
import CoreGraphics
import QuartzCore
import RoundScreenCore

@MainActor
final class CornerOverlayWindow: NSPanel {
    private let overlayView = CornerOverlayView(frame: .zero)
    private var requestedVisible = false
    private var visibilityGeneration = 0
    private(set) var delegatedToSkyLight = false

    init(frame: CGRect, level: NSWindow.Level) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        self.level = level
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        canHide = false
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        sharingType = .none
        title = "RoundScreen Overlay"
        alphaValue = 0

        overlayView.frame = CGRect(origin: .zero, size: frame.size)
        overlayView.autoresizingMask = [.width, .height]
        contentView = overlayView
    }

    func updateFrame(_ frame: CGRect) {
        guard self.frame != frame else { return }
        setFrame(frame, display: true)
        overlayView.frame = CGRect(origin: .zero, size: frame.size)
        overlayView.needsLayout = true
    }

    func setRadii(_ radii: CornerRadiusSet, animated: Bool) {
        overlayView.setRadii(radii, animated: animated)
    }

    func setVisible(_ visible: Bool, animated: Bool) {
        guard requestedVisible != visible else { return }
        requestedVisible = visible
        visibilityGeneration += 1
        let generation = visibilityGeneration

        if visible {
            orderFrontRegardless()
            if animated {
                alphaValue = 0
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.16
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    animator().alphaValue = 1
                }
            } else {
                alphaValue = 1
            }
            return
        }

        guard animated else {
            alphaValue = 0
            orderOut(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.visibilityGeneration == generation else { return }
                self.orderOut(nil)
            }
        }
    }

    func delegateToSkyLightIfNeeded() {
        guard !delegatedToSkyLight else { return }
        SkyLightBridge.shared.delegateWindow(self)
        delegatedToSkyLight = true
    }
}
