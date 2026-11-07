import CoreGraphics

public enum ScreenCorner: String, CaseIterable, Equatable, Hashable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

public enum CornerLayout {
    public static func overlayFrame(
        for corner: ScreenCorner,
        displayFrame: CGRect,
        canvas: CGFloat
    ) -> CGRect {
        let canvas = max(0, canvas)
        guard canvas > 0 else { return .zero }

        let origin: CGPoint = switch corner {
        case .topLeft:
            CGPoint(x: displayFrame.minX, y: displayFrame.maxY - canvas)
        case .topRight:
            CGPoint(x: displayFrame.maxX - canvas, y: displayFrame.maxY - canvas)
        case .bottomLeft:
            CGPoint(x: displayFrame.minX, y: displayFrame.minY)
        case .bottomRight:
            CGPoint(x: displayFrame.maxX - canvas, y: displayFrame.minY)
        }

        return CGRect(
            origin: origin,
            size: CGSize(width: canvas, height: canvas)
        )
    }

}
