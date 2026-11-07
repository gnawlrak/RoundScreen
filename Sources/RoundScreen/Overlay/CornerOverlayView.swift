import AppKit
import QuartzCore
import RoundScreenCore

@MainActor
final class CornerOverlayView: NSView {
    private var shapeLayers: [ScreenCorner: CAShapeLayer] = [:]
    private var radii: CornerRadiusSet = .zero
    private var didLayoutLayers = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        createShapeLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateLayerFrames()
        applyRadii(radii, animated: false)
        didLayoutLayers = true
    }

    func setRadii(_ newRadii: CornerRadiusSet, animated: Bool) {
        let changed = newRadii != radii
        radii = newRadii
        guard changed else { return }
        guard didLayoutLayers || bounds.width > 0 else { return }
        applyRadii(newRadii, animated: animated && changed)
    }

    private func createShapeLayers() {
        for corner in ScreenCorner.allCases {
            let shape = CAShapeLayer()
            shape.fillColor = NSColor.black.cgColor
            shape.fillRule = .nonZero
            shape.masksToBounds = true
            shape.contentsScale = window?.backingScaleFactor ?? 2
            shape.actions = [
                "bounds": NSNull(),
                "frame": NSNull(),
                "position": NSNull(),
                "contentsScale": NSNull(),
            ]
            layer?.addSublayer(shape)
            shapeLayers[corner] = shape
        }
    }

    private func updateLayerFrames() {
        let displayFrame = CGRect(origin: .zero, size: bounds.size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for corner in ScreenCorner.allCases {
            let frame = CornerLayout.overlayFrame(
                for: corner,
                displayFrame: displayFrame,
                canvas: CornerMaskPathBuilder.defaultCanvas
            )
            shapeLayers[corner]?.frame = frame
            shapeLayers[corner]?.contentsScale = window?.backingScaleFactor ?? 2
        }
        CATransaction.commit()
    }

    private func applyRadii(_ newRadii: CornerRadiusSet, animated: Bool) {
        for corner in ScreenCorner.allCases {
            guard let shape = shapeLayers[corner] else { continue }
            let radius = newRadii[corner]
            let path = CornerMaskPathBuilder.path(
                for: corner,
                radius: radius
            )
            let previousPath = shape.presentation()?.path ?? shape.path
            shape.isHidden = false
            shape.path = path

            guard animated,
                  let previousPath,
                  previousPath != path
            else {
                continue
            }

            let animation = CASpringAnimation(keyPath: "path")
            animation.fromValue = previousPath
            animation.toValue = path
            animation.mass = 1
            animation.stiffness = 230
            animation.damping = 27
            animation.initialVelocity = 0
            animation.duration = animation.settlingDuration
            shape.add(animation, forKey: "radius")
        }
    }
}
