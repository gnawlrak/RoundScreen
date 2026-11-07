import AppKit
import CoreGraphics
import Foundation
import RoundScreenCore

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard
            let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber
        else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    var displayIdentifier: String {
        guard let displayID else { return "unknown-display" }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "display-\(displayID)"
    }

    @MainActor
    var displaySnapshot: DisplaySnapshot? {
        guard displayID != nil else { return nil }
        return DisplaySnapshot(
            id: displayIdentifier,
            name: localizedName,
            frame: frame,
            visibleFrame: visibleFrame,
            scale: backingScaleFactor,
            spaceID: SpaceWindowQuery.shared.currentSpace(for: self)
        )
    }
}
