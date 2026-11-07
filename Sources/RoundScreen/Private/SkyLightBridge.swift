import AppKit
import CoreFoundation
import Darwin
import Foundation

@MainActor
final class SkyLightBridge {
    static let shared = SkyLightBridge()

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindows = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let connection: Int32
    private let space: Int32
    private let addWindows: AddWindows?

    private init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
            RTLD_NOW
        )

        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let handle, let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: T.self)
        }

        let mainConnection = symbol("SLSMainConnectionID", as: MainConnectionID.self)
        let spaceCreate = symbol("SLSSpaceCreate", as: SpaceCreate.self)
        let setLevel = symbol("SLSSpaceSetAbsoluteLevel", as: SpaceSetAbsoluteLevel.self)
        let showSpaces = symbol("SLSShowSpaces", as: ShowSpaces.self)
        let addWindows = symbol(
            "SLSSpaceAddWindowsAndRemoveFromSpaces",
            as: AddWindows.self
        )

        guard
            let mainConnection,
            let spaceCreate,
            let setLevel,
            let showSpaces,
            let addWindows
        else {
            connection = 0
            space = 0
            self.addWindows = nil
            return
        }

        connection = mainConnection()
        space = spaceCreate(connection, 1, 0)
        _ = setLevel(connection, space, 400)
        _ = showSpaces(connection, [NSNumber(value: space)] as CFArray)
        self.addWindows = addWindows
    }

    func delegateWindow(_ window: NSWindow) {
        guard space != 0, let addWindows else { return }
        _ = addWindows(
            connection,
            space,
            [NSNumber(value: window.windowNumber)] as CFArray,
            7
        )
    }
}
