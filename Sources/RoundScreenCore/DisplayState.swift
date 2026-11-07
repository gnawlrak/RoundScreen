import CoreGraphics
import Darwin
import Foundation

public enum DisplayState: String, CaseIterable, Equatable, Sendable {
    case normal
    case maximized
    case fullscreen
}

public struct CornerStates: Equatable, Sendable {
    public var topLeft: DisplayState
    public var topRight: DisplayState
    public var bottomLeft: DisplayState
    public var bottomRight: DisplayState

    public init(
        topLeft: DisplayState,
        topRight: DisplayState,
        bottomLeft: DisplayState,
        bottomRight: DisplayState
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public init(_ state: DisplayState) {
        self.init(
            topLeft: state,
            topRight: state,
            bottomLeft: state,
            bottomRight: state
        )
    }

    public static let normal = CornerStates(.normal)
    public static let maximized = CornerStates(.maximized)
    public static let fullscreen = CornerStates(.fullscreen)

    public subscript(corner: ScreenCorner) -> DisplayState {
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

    public var isFullscreen: Bool {
        ScreenCorner.allCases.allSatisfy { self[$0] == .fullscreen }
    }

    public var isUniform: Bool {
        ScreenCorner.allCases.dropFirst().allSatisfy { self[$0] == topLeft }
    }

    public func radii(using profile: CornerRadiusProfile) -> CornerRadiusSet {
        CornerRadiusSet(
            topLeft: profile.radius(for: topLeft),
            topRight: profile.radius(for: topRight),
            bottomLeft: profile.radius(for: bottomLeft),
            bottomRight: profile.radius(for: bottomRight)
        )
    }
}

public struct CornerRadiusSet: Equatable, Sendable {
    public var topLeft: CGFloat
    public var topRight: CGFloat
    public var bottomLeft: CGFloat
    public var bottomRight: CGFloat

    public init(
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomLeft: CGFloat,
        bottomRight: CGFloat
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    public init(_ radius: CGFloat) {
        self.init(
            topLeft: radius,
            topRight: radius,
            bottomLeft: radius,
            bottomRight: radius
        )
    }

    public static let zero = CornerRadiusSet(0)

    public subscript(corner: ScreenCorner) -> CGFloat {
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

public struct DisplaySnapshot: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let scale: CGFloat
    public let spaceID: Int?

    public init(
        id: String,
        name: String,
        frame: CGRect,
        visibleFrame: CGRect,
        scale: CGFloat,
        spaceID: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scale = scale
        self.spaceID = spaceID
    }
}

public struct WindowSnapshot: Identifiable, Equatable, Sendable {
    public let id: CGWindowID
    public let ownerPID: pid_t
    public let layer: Int
    public let alpha: Double
    public let frame: CGRect
    public let isOnscreen: Bool

    public init(
        id: CGWindowID,
        ownerPID: pid_t,
        layer: Int,
        alpha: Double,
        frame: CGRect,
        isOnscreen: Bool = true
    ) {
        self.id = id
        self.ownerPID = ownerPID
        self.layer = layer
        self.alpha = alpha
        self.frame = frame
        self.isOnscreen = isOnscreen
    }
}

public struct DisplayEvaluation: Identifiable, Equatable, Sendable {
    public var id: String { display.id }

    public let display: DisplaySnapshot
    public let corners: CornerStates
    public let sourceWindowIDs: [CGWindowID]

    public init(
        display: DisplaySnapshot,
        corners: CornerStates,
        sourceWindowIDs: [CGWindowID] = []
    ) {
        self.display = display
        self.corners = corners
        self.sourceWindowIDs = sourceWindowIDs
    }
}

public struct CornerRadiusProfile: Equatable, Sendable {
    public var normal: CGFloat
    public var maximized: CGFloat
    public var fullscreen: CGFloat

    public init(
        normal: CGFloat = 20,
        maximized: CGFloat = 14,
        fullscreen: CGFloat = 0
    ) {
        self.normal = normal
        self.maximized = maximized
        self.fullscreen = fullscreen
    }

    public static let standard = CornerRadiusProfile()

    public func radius(for state: DisplayState) -> CGFloat {
        switch state {
        case .normal:
            normal
        case .maximized:
            maximized
        case .fullscreen:
            fullscreen
        }
    }
}
