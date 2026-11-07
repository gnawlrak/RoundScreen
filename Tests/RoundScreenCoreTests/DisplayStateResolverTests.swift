import CoreGraphics
import XCTest
@testable import RoundScreenCore

final class DisplayStateResolverTests: XCTestCase {
    func testBackgroundMaximizedWindowForcesMaximizedCorners() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let maximized = makeWindow(id: 100, frame: display.visibleFrame)
        let foreground = makeWindow(
            id: 200,
            frame: CGRect(x: 280, y: 180, width: 820, height: 560)
        )

        let evaluation = evaluate(display, windows: [foreground, maximized])

        XCTAssertEqual(evaluation.corners, .maximized)
        XCTAssertEqual(evaluation.sourceWindowIDs, [100])
    }

    func testAnyMaximizedWindowForcesMaximizedCorners() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let foreground = makeWindow(
            id: 300,
            frame: CGRect(x: 280, y: 180, width: 820, height: 560)
        )
        let normalWindow = makeWindow(
            id: 200,
            frame: CGRect(x: 120, y: 100, width: 700, height: 500)
        )
        let maximized = makeWindow(id: 100, frame: display.visibleFrame)

        let evaluation = evaluate(
            display,
            windows: [foreground, normalWindow, maximized]
        )

        XCTAssertEqual(evaluation.corners, .maximized)
        XCTAssertEqual(evaluation.sourceWindowIDs, [100])
    }

    func testOneTouchingCornerOnlyLowersThatCorner() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let bottomLeftWindow = makeWindow(
            id: 100,
            frame: CGRect(x: 0, y: 0, width: 620, height: 520)
        )

        let evaluation = evaluate(display, windows: [bottomLeftWindow])

        XCTAssertEqual(evaluation.corners.topLeft, .normal)
        XCTAssertEqual(evaluation.corners.topRight, .normal)
        XCTAssertEqual(evaluation.corners.bottomLeft, .maximized)
        XCTAssertEqual(evaluation.corners.bottomRight, .normal)
    }

    func testFullscreenOnlyHidesItsOwnDisplay() {
        let displayA = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let displayB = makeDisplay(
            id: "B",
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        )
        let fullscreenA = makeWindow(id: 100, frame: displayA.frame)
        let maximizedB = makeWindow(id: 200, frame: displayB.visibleFrame)

        let evaluations = DisplayStateResolver.evaluate(
            displays: [displayA, displayB],
            frontToBackWindows: [fullscreenA, maximizedB]
        )

        XCTAssertEqual(state(of: "A", in: evaluations), .fullscreen)
        XCTAssertEqual(state(of: "B", in: evaluations), .maximized)
    }

    func testNativeFullscreenHidesDisplayAtVisibleFrameSize() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let maximized = makeWindow(id: 100, frame: display.visibleFrame)

        let evaluations = DisplayStateResolver.evaluate(
            displays: [display],
            frontToBackWindows: [maximized],
            nativeFullscreenFrames: [display.visibleFrame]
        )

        XCTAssertEqual(evaluations[0].corners, .fullscreen)
    }

    func testNativeFullscreenTakesPrecedenceOverFloatingWindow() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let floating = makeWindow(
            id: 200,
            frame: CGRect(x: 240, y: 180, width: 620, height: 420)
        )

        let evaluations = DisplayStateResolver.evaluate(
            displays: [display],
            frontToBackWindows: [floating],
            nativeFullscreenFrames: [display.visibleFrame]
        )

        XCTAssertEqual(evaluations[0].corners, .fullscreen)
    }

    func testNativeFullscreenOnlyHidesItsOwnDisplay() {
        let displayA = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let displayB = makeDisplay(
            id: "B",
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        )
        let normalB = makeWindow(
            id: 200,
            frame: CGRect(x: 1700, y: 220, width: 800, height: 560)
        )

        let evaluations = DisplayStateResolver.evaluate(
            displays: [displayA, displayB],
            frontToBackWindows: [normalB],
            nativeFullscreenFrames: [displayA.frame]
        )

        XCTAssertEqual(state(of: "A", in: evaluations), .fullscreen)
        XCTAssertEqual(state(of: "B", in: evaluations), .normal)
    }

    func testBackgroundFullscreenWindowWinsOverFrontmostWindow() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let floating = makeWindow(
            id: 200,
            frame: CGRect(x: 280, y: 180, width: 820, height: 560)
        )
        let fullscreen = makeWindow(id: 100, frame: display.frame)

        let evaluation = evaluate(
            display,
            windows: [floating, fullscreen]
        )

        XCTAssertEqual(evaluation.corners, .fullscreen)
        XCTAssertEqual(evaluation.sourceWindowIDs, [100])
    }

    func testMaximizedDisplayDoesNotAffectAnotherDisplay() {
        let displayA = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )
        let displayB = makeDisplay(
            id: "B",
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        )
        let normalA = makeWindow(
            id: 100,
            frame: CGRect(x: 200, y: 160, width: 800, height: 560)
        )
        let maximizedB = makeWindow(id: 200, frame: displayB.visibleFrame)

        let evaluations = DisplayStateResolver.evaluate(
            displays: [displayA, displayB],
            frontToBackWindows: [normalA, maximizedB]
        )

        XCTAssertEqual(state(of: "A", in: evaluations), .normal)
        XCTAssertEqual(state(of: "B", in: evaluations), .maximized)
    }

    func testOffscreenWindowIsNotUsedForCurrentSpace() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875),
            spaceID: 10
        )
        let maximizedButOffscreen = makeWindow(
            id: 100,
            frame: display.visibleFrame,
            isOnscreen: false
        )
        let normalOnCurrentSpace = makeWindow(
            id: 200,
            frame: CGRect(x: 300, y: 200, width: 700, height: 500)
        )

        let evaluation = evaluate(
            display,
            windows: [normalOnCurrentSpace, maximizedButOffscreen]
        )

        XCTAssertEqual(evaluation.corners, .normal)
        XCTAssertEqual(evaluation.sourceWindowIDs, [])
    }

    func testDisplayWithoutLargeWindowIsNormal() {
        let display = makeDisplay(
            id: "A",
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
        )

        let evaluation = evaluate(display, windows: [])

        XCTAssertEqual(evaluation.corners, .normal)
        XCTAssertTrue(evaluation.sourceWindowIDs.isEmpty)
    }

    func testWindowServerCoordinatesConvertToAppKitCoordinates() {
        let converted = WindowGeometry.appKitFrame(
            fromWindowServerBounds: CGRect(x: 100, y: 50, width: 400, height: 300),
            primaryDisplayHeight: 900
        )

        XCTAssertEqual(
            converted,
            CGRect(x: 100, y: 550, width: 400, height: 300)
        )
    }

    func testOverlayLayersUseAFixedCanvasAtEveryCorner() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)

        XCTAssertEqual(
            CornerLayout.overlayFrame(
                for: .topLeft,
                displayFrame: frame,
                canvas: 80
            ),
            CGRect(x: 0, y: 720, width: 80, height: 80)
        )
        XCTAssertEqual(
            CornerLayout.overlayFrame(
                for: .topRight,
                displayFrame: frame,
                canvas: 80
            ),
            CGRect(x: 920, y: 720, width: 80, height: 80)
        )
        XCTAssertEqual(
            CornerLayout.overlayFrame(
                for: .bottomLeft,
                displayFrame: frame,
                canvas: 80
            ),
            CGRect(x: 0, y: 0, width: 80, height: 80)
        )
        XCTAssertEqual(
            CornerLayout.overlayFrame(
                for: .bottomRight,
                displayFrame: frame,
                canvas: 80
            ),
            CGRect(x: 920, y: 0, width: 80, height: 80)
        )
    }

    func testRadiusProfileUsesMeasuredDefaults() {
        let profile = CornerRadiusProfile.standard

        XCTAssertEqual(profile.radius(for: .normal), 20)
        XCTAssertEqual(profile.radius(for: .maximized), 14)
        XCTAssertEqual(profile.radius(for: .fullscreen), 0)
    }

    func testContinuousCornerPathHasStableStructure() {
        let radii: [CGFloat] = [0, 20, 27, 60]
        let counts = radii.map { radius in
            var count = 0
            CornerMaskPathBuilder.path(
                for: .topLeft,
                radius: radius
            ).applyWithBlock { _ in
                count += 1
            }
            return count
        }

        XCTAssertEqual(counts, [7, 7, 7, 7])
    }

    func testZeroRadiusPathHasNoVisibleArea() {
        let path = CornerMaskPathBuilder.path(
            for: .topLeft,
            radius: 0,
            canvas: 80
        )

        XCTAssertEqual(path.boundingBox.width, 0)
        XCTAssertEqual(path.boundingBox.height, 0)
    }

    func testCornerPathOccupiesOnlyTheOuterSliver() {
        let path = CornerMaskPathBuilder.path(
            for: .topLeft,
            radius: 27,
            canvas: 80
        )

        XCTAssertEqual(
            path.boundingBox,
            CGRect(x: 0, y: 53, width: 27, height: 27)
        )
    }

    private func evaluate(
        _ display: DisplaySnapshot,
        windows: [WindowSnapshot]
    ) -> DisplayEvaluation {
        DisplayStateResolver.evaluate(
            displays: [display],
            frontToBackWindows: windows
        )[0]
    }

    private func makeDisplay(
        id: String,
        frame: CGRect,
        visibleFrame: CGRect,
        spaceID: Int? = nil
    ) -> DisplaySnapshot {
        DisplaySnapshot(
            id: id,
            name: id,
            frame: frame,
            visibleFrame: visibleFrame,
            scale: 2,
            spaceID: spaceID
        )
    }

    private func makeWindow(
        id: CGWindowID,
        frame: CGRect,
        isOnscreen: Bool = true
    ) -> WindowSnapshot {
        WindowSnapshot(
            id: id,
            ownerPID: 1,
            layer: 0,
            alpha: 1,
            frame: frame,
            isOnscreen: isOnscreen
        )
    }

    private func state(
        of displayID: String,
        in evaluations: [DisplayEvaluation]
    ) -> DisplayState? {
        guard let evaluation = evaluations.first(where: { $0.id == displayID }) else {
            return nil
        }
        if evaluation.corners.isFullscreen {
            return .fullscreen
        }
        if evaluation.corners.isUniform {
            return evaluation.corners.topLeft
        }
        return nil
    }
}
