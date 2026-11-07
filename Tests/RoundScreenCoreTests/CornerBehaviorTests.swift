import CoreGraphics
import XCTest
@testable import RoundScreenCore

final class CornerCursorGeometryTests: XCTestCase {
    private let displayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testTopLeftPointIsClampedOutOfTheSliver() {
        let point = CGPoint(x: 1, y: 899)
        guard let clamped = CornerCursorGeometry.clampedPoint(
            for: point,
            displayFrame: displayFrame,
            corner: .topLeft,
            radius: 20
        ) else {
            return XCTFail("expected a clamped point")
        }

        let cornerFrame = CornerLayout.overlayFrame(
            for: .topLeft,
            displayFrame: displayFrame,
            canvas: 80
        )
        let path = CornerMaskPathBuilder.path(
            for: .topLeft,
            radius: 20,
            canvas: 80
        )
        let local = CGPoint(
            x: clamped.x - cornerFrame.minX,
            y: clamped.y - cornerFrame.minY
        )
        XCTAssertFalse(path.contains(local, using: .winding))
    }

    func testPointInsideTheCornerCanvasButOutsideTheSliverIsNotClamped() {
        XCTAssertNil(
            CornerCursorGeometry.clampedPoint(
                for: CGPoint(x: 10, y: 830),
                displayFrame: displayFrame,
                corner: .topLeft,
                radius: 20
            )
        )
    }

    func testExactScreenCornerIsClamped() {
        let topLeft = CornerCursorGeometry.clampedPoint(
            for: CGPoint(x: 0, y: 900),
            displayFrame: displayFrame,
            corner: .topLeft,
            radius: 20
        )
        XCTAssertNotNil(topLeft)

        let bottomRight = CornerCursorGeometry.clampedPoint(
            for: CGPoint(x: 1440, y: 0),
            displayFrame: displayFrame,
            corner: .bottomRight,
            radius: 20
        )
        XCTAssertNotNil(bottomRight)
    }

    func testZeroRadiusDoesNotClamp() {
        XCTAssertNil(
            CornerCursorGeometry.clampedPoint(
                for: CGPoint(x: 1, y: 1),
                displayFrame: displayFrame,
                corner: .bottomLeft,
                radius: 0
            )
        )
    }

    func testInnerCurveUsesTheCornerTransform() {
        let points = CornerMaskPathBuilder.innerCurvePoints(
            for: .topLeft,
            radius: 20,
            canvas: 80,
            samplesPerSegment: 4
        )

        XCTAssertEqual(points.first?.x ?? -1, 20, accuracy: 0.001)
        XCTAssertEqual(points.first?.y ?? -1, 80, accuracy: 0.001)
        XCTAssertEqual(points.last?.x ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(points.last?.y ?? -1, 60, accuracy: 0.001)
    }

    func testDistanceIsZeroOnTheInnerCurve() {
        let curve = CornerMaskPathBuilder.innerCurvePoints(
            for: .bottomRight,
            radius: 20,
            canvas: 80,
            samplesPerSegment: 16
        )
        let cornerFrame = CornerLayout.overlayFrame(
            for: .bottomRight,
            displayFrame: displayFrame,
            canvas: 80
        )
        let point = CGPoint(
            x: cornerFrame.minX + curve[curve.count / 2].x,
            y: cornerFrame.minY + curve[curve.count / 2].y
        )

        let distance = CornerCursorGeometry.distanceToInnerCurve(
            for: point,
            displayFrame: displayFrame,
            corner: .bottomRight,
            radius: 20
        )
        XCTAssertEqual(distance ?? .infinity, 0, accuracy: 0.001)
    }

    func testDeepPointInsideCornerCanvasIsOutsideHotCornerTolerance() {
        let distance = CornerCursorGeometry.distanceToInnerCurve(
            for: CGPoint(x: 1380, y: 20),
            displayFrame: displayFrame,
            corner: .bottomRight,
            radius: 20
        )
        XCTAssertGreaterThan(distance ?? 0, 6)
    }
}
