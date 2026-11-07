import CoreGraphics
import Darwin
import Foundation
import RoundScreenCore

@MainActor
enum WindowSnapshotProvider {
    struct Scan {
        let isMissionControlActive: Bool
        let windows: [WindowSnapshot]
    }

    private static let systemOwners: Set<String> = [
        "Window Server",
        "Dock",
        "SystemUIServer",
        "Control Center",
        "WindowManager",
    ]

    static func scan(
        excludingPID excludedPID: pid_t,
        primaryDisplayHeight: CGFloat
    ) -> Scan {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(
            options,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return Scan(isMissionControlActive: false, windows: [])
        }

        let isMissionControlActive = rawWindows.contains { info in
            guard
                let owner = info[kCGWindowOwnerName as String] as? String,
                let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                let name = info[kCGWindowName as String] as? String
            else {
                return false
            }
            return owner == "WindowManager"
                && layer == 19
                && name == "ExposeShieldWindow"
        }

        let windows = rawWindows.compactMap { info -> WindowSnapshot? in
            guard
                let ownerPIDNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
                ownerPIDNumber.int32Value != excludedPID
            else {
                return nil
            }

            if
                let ownerName = info[kCGWindowOwnerName as String] as? String,
                systemOwners.contains(ownerName)
            {
                return nil
            }

            guard
                let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                layer == 0,
                let windowIDNumber = info[kCGWindowNumber as String] as? NSNumber,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let x = (boundsDictionary["X"] as? NSNumber)?.doubleValue,
                let y = (boundsDictionary["Y"] as? NSNumber)?.doubleValue,
                let width = (boundsDictionary["Width"] as? NSNumber)?.doubleValue,
                let height = (boundsDictionary["Height"] as? NSNumber)?.doubleValue
            else {
                return nil
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            let isOnscreen = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue
                ?? true
            guard isOnscreen, alpha > 0.01, bounds.width >= 80, bounds.height >= 80 else {
                return nil
            }

            return WindowSnapshot(
                id: CGWindowID(windowIDNumber.uint32Value),
                ownerPID: ownerPIDNumber.int32Value,
                layer: layer,
                alpha: alpha,
                frame: WindowGeometry.appKitFrame(
                    fromWindowServerBounds: bounds,
                    primaryDisplayHeight: primaryDisplayHeight
                ),
                isOnscreen: isOnscreen
            )
        }
        return Scan(
            isMissionControlActive: isMissionControlActive,
            windows: windows
        )
    }
}
