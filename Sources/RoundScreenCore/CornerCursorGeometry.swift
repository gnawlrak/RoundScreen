import CoreGraphics

public enum CornerCursorGeometry {
    public static func clampedPoint(
        for point: CGPoint,
        displayFrame: CGRect,
        corner: ScreenCorner,
        radius: CGFloat,
        canvas: CGFloat = CornerMaskPathBuilder.defaultCanvas
    ) -> CGPoint? {
        guard radius >= CornerMaskPathBuilder.minimumRadius else { return nil }

        let cornerFrame = CornerLayout.overlayFrame(
            for: corner,
            displayFrame: displayFrame,
            canvas: canvas
        )
        guard containsInclusive(point, in: cornerFrame) else { return nil }

        let local = CGPoint(
            x: point.x - cornerFrame.minX,
            y: point.y - cornerFrame.minY
        )
        let center = CGPoint(
            x: displayFrame.midX - cornerFrame.minX,
            y: displayFrame.midY - cornerFrame.minY
        )
        let centerLength = hypot(center.x, center.y)
        let boundaryProbe = centerLength > 0
            ? CGPoint(
                x: local.x + center.x / centerLength * 0.75,
                y: local.y + center.y / centerLength * 0.75
            )
            : local
        let path = CornerMaskPathBuilder.path(
            for: corner,
            radius: radius,
            canvas: canvas
        )
        guard path.contains(local, using: .winding)
                || path.contains(boundaryProbe, using: .winding)
        else {
            return nil
        }

        let curve = CornerMaskPathBuilder.innerCurvePoints(
            for: corner,
            radius: radius,
            canvas: canvas
        )
        guard let nearest = nearestPoint(on: curve, to: local) else {
            return nil
        }

        let inward = CGPoint(
            x: displayFrame.midX - cornerFrame.minX - nearest.x,
            y: displayFrame.midY - cornerFrame.minY - nearest.y
        )
        let length = hypot(inward.x, inward.y)
        let bias: CGFloat = 1.5
        let biased = length > 0
            ? CGPoint(
                x: nearest.x + inward.x / length * bias,
                y: nearest.y + inward.y / length * bias
            )
            : nearest

        return CGPoint(
            x: cornerFrame.minX + biased.x,
            y: cornerFrame.minY + biased.y
        )
    }

    public static func distanceToInnerCurve(
        for point: CGPoint,
        displayFrame: CGRect,
        corner: ScreenCorner,
        radius: CGFloat,
        canvas: CGFloat = CornerMaskPathBuilder.defaultCanvas
    ) -> CGFloat? {
        guard radius >= CornerMaskPathBuilder.minimumRadius else { return nil }

        let cornerFrame = CornerLayout.overlayFrame(
            for: corner,
            displayFrame: displayFrame,
            canvas: canvas
        )
        guard containsInclusive(point, in: cornerFrame) else { return nil }

        let local = CGPoint(
            x: point.x - cornerFrame.minX,
            y: point.y - cornerFrame.minY
        )
        let curve = CornerMaskPathBuilder.innerCurvePoints(
            for: corner,
            radius: radius,
            canvas: canvas
        )
        guard let nearest = nearestPoint(on: curve, to: local) else {
            return nil
        }
        return hypot(nearest.x - local.x, nearest.y - local.y)
    }

    private static func nearestPoint(
        on curve: [CGPoint],
        to point: CGPoint
    ) -> CGPoint? {
        guard !curve.isEmpty else { return nil }
        var nearest = curve[0]
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for candidate in curve {
            let distance = hypot(candidate.x - point.x, candidate.y - point.y)
            if distance < nearestDistance {
                nearest = candidate
                nearestDistance = distance
            }
        }
        return nearest
    }

    private static func containsInclusive(
        _ point: CGPoint,
        in rect: CGRect
    ) -> Bool {
        point.x >= rect.minX
            && point.x <= rect.maxX
            && point.y >= rect.minY
            && point.y <= rect.maxY
    }
}
