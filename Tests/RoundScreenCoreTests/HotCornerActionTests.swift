import CoreGraphics
import XCTest
@testable import RoundScreenCore

final class HotCornerActionTests: XCTestCase {
    func testDockActionValuesMapToNativeActions() {
        XCTAssertEqual(
            HotCornerAction(dockValue: 2),
            .missionControl
        )
        XCTAssertEqual(
            HotCornerAction(dockValue: 3),
            .applicationWindows
        )
        XCTAssertEqual(
            HotCornerAction(dockValue: 4),
            .showDesktop
        )
        XCTAssertEqual(
            HotCornerAction(dockValue: 5),
            .startScreenSaver
        )
        XCTAssertEqual(
            HotCornerAction(dockValue: 11),
            .launchpad
        )
    }

    func testNoActionAndUnknownValuesAreIgnored() {
        XCTAssertNil(HotCornerAction(dockValue: 0))
        XCTAssertNil(HotCornerAction(dockValue: 1))
        XCTAssertNil(HotCornerAction(dockValue: 99))
    }

    func testBindingWithoutModifierAlwaysMatches() {
        let binding = HotCornerBinding(
            action: .missionControl,
            modifierRawValue: 0
        )

        XCTAssertTrue(binding.matches(eventFlags: []))
        XCTAssertTrue(binding.matches(eventFlags: [.maskCommand]))
    }

    func testBindingRequiresTheConfiguredModifier() {
        let binding = HotCornerBinding(
            action: .launchpad,
            modifierRawValue: UInt32(
                truncatingIfNeeded: CGEventFlags.maskControl.rawValue
            )
        )

        XCTAssertTrue(binding.matches(eventFlags: .maskControl))
        XCTAssertFalse(binding.matches(eventFlags: []))
        XCTAssertFalse(
            binding.matches(
                eventFlags: CGEventFlags.maskControl.union(.maskShift)
            )
        )
    }
}
