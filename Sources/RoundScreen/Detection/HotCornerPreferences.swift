import CoreFoundation
import Foundation
import RoundScreenCore

enum HotCornerPreferences {
    private static let dockDomain = "com.apple.dock"

    static func bindings() -> HotCornerBindings {
        HotCornerBindings(
            topLeft: binding(for: .topLeft),
            topRight: binding(for: .topRight),
            bottomLeft: binding(for: .bottomLeft),
            bottomRight: binding(for: .bottomRight)
        )
    }

    static func binding(for corner: ScreenCorner) -> HotCornerBinding? {
        let code = cornerCode(corner)
        guard let rawAction = integerValue(for: "wvous-\(code)-corner"),
              let action = HotCornerAction(dockValue: rawAction)
        else {
            return nil
        }

        let rawModifier = integerValue(for: "wvous-\(code)-modifier") ?? 0
        return HotCornerBinding(
            action: action,
            modifierRawValue: UInt32(clamping: rawModifier)
        )
    }

    private static func integerValue(for key: String) -> Int? {
        guard let value = CFPreferencesCopyAppValue(
            key as CFString,
            dockDomain as CFString
        ) else {
            return nil
        }
        return (value as? NSNumber)?.intValue
    }

    private static func cornerCode(_ corner: ScreenCorner) -> String {
        switch corner {
        case .topLeft:
            "tl"
        case .topRight:
            "tr"
        case .bottomLeft:
            "bl"
        case .bottomRight:
            "br"
        }
    }
}
