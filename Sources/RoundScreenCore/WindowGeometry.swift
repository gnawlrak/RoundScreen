import CoreGraphics

public enum WindowGeometry {
    public static func appKitFrame(
        fromWindowServerBounds bounds: CGRect,
        primaryDisplayHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: bounds.minX,
            y: primaryDisplayHeight - bounds.maxY,
            width: bounds.width,
            height: bounds.height
        )
    }

    public static func approximatelyEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        tolerance: CGFloat
    ) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.maxX - rhs.maxX) <= tolerance
            && abs(lhs.maxY - rhs.maxY) <= tolerance
    }
}
