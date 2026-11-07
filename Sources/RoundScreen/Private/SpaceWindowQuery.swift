import AppKit
import CoreGraphics
import Foundation

private typealias SpaceConnectionID = Int32
private typealias CGSSpaceID = Int

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> SpaceConnectionID

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ connection: SpaceConnectionID) -> CGSSpaceID

@_silgen_name("CGSManagedDisplayGetCurrentSpace")
private func CGSManagedDisplayGetCurrentSpace(
    _ connection: SpaceConnectionID,
    _ displayUUID: CFString
) -> CGSSpaceID

@MainActor
final class SpaceWindowQuery {
    static let shared = SpaceWindowQuery()

    private let connection: SpaceConnectionID

    private init() {
        connection = CGSMainConnectionID()
    }

    func currentSpace(for screen: NSScreen) -> Int? {
        if let uuid = displayUUID(for: screen) {
            let managedSpace = CGSManagedDisplayGetCurrentSpace(connection, uuid)
            if managedSpace != 0 {
                return managedSpace
            }
        }
        guard screen == NSScreen.main else { return nil }
        let activeSpace = CGSGetActiveSpace(connection)
        return activeSpace == 0 ? nil : activeSpace
    }

    private func displayUUID(for screen: NSScreen) -> CFString? {
        guard
            let displayID = screen.displayID,
            let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        else {
            return nil
        }
        return CFUUIDCreateString(nil, uuid)
    }
}
