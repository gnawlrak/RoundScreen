import AppKit
import Foundation

private typealias CGSConnectionID = UInt
private typealias CGSSpaceID = UInt64

@_silgen_name("_CGSDefaultConnection")
private func CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(
    _ connection: CGSConnectionID,
    _ unknown: Int,
    _ options: NSDictionary?
) -> CGSSpaceID

@_silgen_name("CGSSpaceDestroy")
private func CGSSpaceDestroy(_ connection: CGSConnectionID, _ space: CGSSpaceID)

@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(
    _ connection: CGSConnectionID,
    _ space: CGSSpaceID,
    _ level: Int
)

@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(
    _ connection: CGSConnectionID,
    _ windows: NSArray,
    _ spaces: NSArray
)

@_silgen_name("CGSRemoveWindowsFromSpaces")
private func CGSRemoveWindowsFromSpaces(
    _ connection: CGSConnectionID,
    _ windows: NSArray,
    _ spaces: NSArray
)

@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ connection: CGSConnectionID, _ spaces: NSArray)

@_silgen_name("CGSHideSpaces")
private func CGSHideSpaces(_ connection: CGSConnectionID, _ spaces: NSArray)

final class PersistentSpace {
    private let connection: CGSConnectionID
    private let space: CGSSpaceID

    init(level: Int = Int(Int32.max)) {
        connection = CGSDefaultConnection()
        space = CGSSpaceCreate(connection, 1, nil)
        CGSSpaceSetAbsoluteLevel(connection, space, level)
        CGSShowSpaces(connection, [space] as NSArray)
    }

    @MainActor
    func attach(_ window: NSWindow) {
        CGSAddWindowsToSpaces(
            connection,
            [window.windowNumber] as NSArray,
            [space] as NSArray
        )
    }

    @MainActor
    func detach(_ window: NSWindow) {
        CGSRemoveWindowsFromSpaces(
            connection,
            [window.windowNumber] as NSArray,
            [space] as NSArray
        )
    }

    deinit {
        CGSHideSpaces(connection, [space] as NSArray)
        CGSSpaceDestroy(connection, space)
    }
}
