import CoreGraphics

public enum HotCornerAction: Int, CaseIterable, Equatable, Sendable {
    case missionControl = 2
    case applicationWindows = 3
    case showDesktop = 4
    case startScreenSaver = 5
    case disableScreenSaver = 6
    case dashboard = 7
    case sleepDisplay = 10
    case launchpad = 11
    case notificationCenter = 12
    case lockScreen = 13
    case quickNote = 14

    public init?(dockValue: Int) {
        guard let action = Self(rawValue: dockValue) else { return nil }
        self = action
    }

    public var displayName: String {
        switch self {
        case .missionControl:
            "调度中心"
        case .applicationWindows:
            "App Exposé"
        case .showDesktop:
            "显示桌面"
        case .startScreenSaver:
            "启动屏幕保护程序"
        case .disableScreenSaver:
            "停用屏幕保护程序"
        case .dashboard:
            "Dashboard"
        case .sleepDisplay:
            "关闭显示器"
        case .launchpad:
            "启动台"
        case .notificationCenter:
            "通知中心"
        case .lockScreen:
            "锁定屏幕"
        case .quickNote:
            "快速备忘录"
        }
    }
}

public struct HotCornerBinding: Equatable, Sendable {
    public let action: HotCornerAction
    public let modifierRawValue: UInt32

    public init(action: HotCornerAction, modifierRawValue: UInt32 = 0) {
        self.action = action
        self.modifierRawValue = modifierRawValue
    }

    public var requiredModifiers: CGEventFlags {
        CGEventFlags(rawValue: UInt64(modifierRawValue))
            .intersection(Self.modifierMask)
    }

    public func matches(eventFlags: CGEventFlags) -> Bool {
        let requiredModifiers = requiredModifiers
        guard !requiredModifiers.isEmpty else { return true }
        return eventFlags.intersection(Self.modifierMask) == requiredModifiers
    }

    private static let modifierMask: CGEventFlags = [
        .maskShift,
        .maskControl,
        .maskAlternate,
        .maskCommand,
    ]
}

public struct HotCornerBindings: Equatable, Sendable {
    public var topLeft: HotCornerBinding?
    public var topRight: HotCornerBinding?
    public var bottomLeft: HotCornerBinding?
    public var bottomRight: HotCornerBinding?

    public init(
        topLeft: HotCornerBinding? = nil,
        topRight: HotCornerBinding? = nil,
        bottomLeft: HotCornerBinding? = nil,
        bottomRight: HotCornerBinding? = nil
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public subscript(corner: ScreenCorner) -> HotCornerBinding? {
        get {
            switch corner {
            case .topLeft:
                topLeft
            case .topRight:
                topRight
            case .bottomLeft:
                bottomLeft
            case .bottomRight:
                bottomRight
            }
        }
        set {
            switch corner {
            case .topLeft:
                topLeft = newValue
            case .topRight:
                topRight = newValue
            case .bottomLeft:
                bottomLeft = newValue
            case .bottomRight:
                bottomRight = newValue
            }
        }
    }
}
