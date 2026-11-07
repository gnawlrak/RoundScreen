import AppKit
import ApplicationServices
import CoreGraphics
import RoundScreenCore

@MainActor
enum NativeFullscreenProvider {
    static func frames(primaryDisplayHeight: CGFloat) -> [CGRect] {
        guard
            AXIsProcessTrusted(),
            let application = NSWorkspace.shared.frontmostApplication
        else {
            return []
        }

        let axApplication = AXUIElementCreateApplication(
            application.processIdentifier
        )
        guard let windows = copyWindows(from: axApplication) else {
            return []
        }

        return windows.compactMap { window in
            guard isFullscreen(window),
                  let position = pointAttribute(kAXPositionAttribute, of: window),
                  let size = sizeAttribute(kAXSizeAttribute, of: window),
                  size.width >= DisplayStateResolver.minimumWindowSize,
                  size.height >= DisplayStateResolver.minimumWindowSize
            else {
                return nil
            }

            return WindowGeometry.appKitFrame(
                fromWindowServerBounds: CGRect(origin: position, size: size),
                primaryDisplayHeight: primaryDisplayHeight
            )
        }
    }

    private static func copyWindows(from application: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private static func isFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window,
            "AXFullScreen" as CFString,
            &value
        ) == .success else {
            return false
        }
        return (value as? NSNumber)?.boolValue == true
    }

    private static func pointAttribute(
        _ attribute: String,
        of element: AXUIElement
    ) -> CGPoint? {
        guard let value = axValue(attribute, of: element) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func sizeAttribute(
        _ attribute: String,
        of element: AXUIElement
    ) -> CGSize? {
        guard let value = axValue(attribute, of: element) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(
        _ attribute: String,
        of element: AXUIElement
    ) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        return (value as! AXValue)
    }
}
