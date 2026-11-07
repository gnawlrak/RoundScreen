import CoreGraphics
import Darwin
import Foundation

public enum DisplayStateResolver {
    public static let fullscreenTolerance: CGFloat = 2
    public static let maximizedTolerance: CGFloat = 6
    public static let cornerTolerance: CGFloat = 12
    public static let minimumWindowSize: CGFloat = 80

    public static func evaluate(
        displays: [DisplaySnapshot],
        frontToBackWindows windows: [WindowSnapshot],
        nativeFullscreenFrames: [CGRect] = []
    ) -> [DisplayEvaluation] {
        let nativeFullscreenDisplayIDs = Set(
            nativeFullscreenFrames.compactMap { frame in
                displayID(containing: frame, displays: displays)
            }
        )

        return displays.map { display in
            if nativeFullscreenDisplayIDs.contains(display.id) {
                return DisplayEvaluation(
                    display: display,
                    corners: .fullscreen,
                    sourceWindowIDs: []
                )
            }

            let eligibleWindows = windows.filter { window in
                isEligible(window, on: display)
            }
            guard let frontmostWindow = eligibleWindows.first else {
                return DisplayEvaluation(
                    display: display,
                    corners: .normal,
                    sourceWindowIDs: []
                )
            }

            if WindowGeometry.approximatelyEqual(
                frontmostWindow.frame,
                display.frame,
                tolerance: fullscreenTolerance
            ) {
                return DisplayEvaluation(
                    display: display,
                    corners: .fullscreen,
                    sourceWindowIDs: [frontmostWindow.id]
                )
            }

            let maximizedWindows = eligibleWindows.filter { window in
                WindowGeometry.approximatelyEqual(
                    window.frame,
                    display.visibleFrame,
                    tolerance: maximizedTolerance
                )
            }
            if !maximizedWindows.isEmpty {
                return DisplayEvaluation(
                    display: display,
                    corners: .maximized,
                    sourceWindowIDs: maximizedWindows.map(\.id)
                )
            }

            var corners = CornerStates.normal
            var touchesAnyCorner = false
            for corner in ScreenCorner.allCases where touches(
                corner: corner,
                windowFrame: frontmostWindow.frame,
                displayFrame: display.frame
            ) {
                corners[corner] = .maximized
                touchesAnyCorner = true
            }
            return DisplayEvaluation(
                display: display,
                corners: corners,
                sourceWindowIDs: touchesAnyCorner ? [frontmostWindow.id] : []
            )
        }
    }

    public static func displayID(
        containing frame: CGRect,
        displays: [DisplaySnapshot]
    ) -> String? {
        displays.max { lhs, rhs in
            intersectionArea(lhs.frame, frame) < intersectionArea(rhs.frame, frame)
        }
        .flatMap { display in
            intersectionArea(display.frame, frame) > 0 ? display.id : nil
        }
    }

    public static func isEligible(
        _ window: WindowSnapshot,
        on display: DisplaySnapshot
    ) -> Bool {
        guard window.layer == 0, window.alpha > 0.01, window.isOnscreen else {
            return false
        }
        guard window.frame.width >= minimumWindowSize,
              window.frame.height >= minimumWindowSize
        else {
            return false
        }
        return window.frame.intersects(display.frame)
    }

    public static func touches(
        corner: ScreenCorner,
        windowFrame: CGRect,
        displayFrame: CGRect
    ) -> Bool {
        let screenPoint = cornerPoint(of: displayFrame, corner: corner)
        let windowPoint = cornerPoint(of: windowFrame, corner: corner)
        return abs(screenPoint.x - windowPoint.x) <= cornerTolerance
            && abs(screenPoint.y - windowPoint.y) <= cornerTolerance
    }

    public static func cornerPoint(
        of frame: CGRect,
        corner: ScreenCorner
    ) -> CGPoint {
        switch corner {
        case .topLeft:
            CGPoint(x: frame.minX, y: frame.maxY)
        case .topRight:
            CGPoint(x: frame.maxX, y: frame.maxY)
        case .bottomLeft:
            CGPoint(x: frame.minX, y: frame.minY)
        case .bottomRight:
            CGPoint(x: frame.maxX, y: frame.minY)
        }
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }
}
