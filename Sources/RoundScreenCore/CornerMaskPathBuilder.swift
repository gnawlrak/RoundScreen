import CoreGraphics

public enum CornerMaskPathBuilder {
    public static let defaultCanvas: CGFloat = 80
    public static let minimumRadius: CGFloat = 0.5
    public static let minimumPathRadius: CGFloat = 0

    private static let firstCurvePoint = CGPoint(x: 0.631493, y: 0.074911)
    private static let secondCurvePoint = CGPoint(x: 0.074911, y: 0.631493)
    private static let firstCurveControl = CGPoint(x: 0.96, y: 0.0)
    private static let secondCurveControl = CGPoint(x: 0.82, y: 0.0)
    private static let thirdCurveControl = CGPoint(x: 0.372824, y: 0.169060)
    private static let fourthCurveControl = CGPoint(x: 0.169060, y: 0.372824)
    private static let fifthCurveControl = CGPoint(x: 0.0, y: 0.82)
    private static let sixthCurveControl = CGPoint(x: 0.0, y: 0.96)

    public static func path(
        for corner: ScreenCorner,
        radius: CGFloat,
        canvas: CGFloat = defaultCanvas
    ) -> CGPath {
        guard canvas > 0 else { return CGMutablePath() }
        let canvas = max(canvas, 1)
        let radius = min(max(radius, minimumPathRadius), canvas)

        let local = CGMutablePath()
        local.move(to: .zero)
        local.addLine(to: CGPoint(x: radius, y: 0))
        local.addCurve(
            to: scaled(firstCurvePoint, by: radius),
            control1: scaled(firstCurveControl, by: radius),
            control2: scaled(secondCurveControl, by: radius)
        )
        local.addCurve(
            to: scaled(secondCurvePoint, by: radius),
            control1: scaled(thirdCurveControl, by: radius),
            control2: scaled(fourthCurveControl, by: radius)
        )
        local.addCurve(
            to: CGPoint(x: 0, y: radius),
            control1: scaled(fifthCurveControl, by: radius),
            control2: scaled(sixthCurveControl, by: radius)
        )
        local.addLine(to: .zero)
        local.closeSubpath()

        var transform = transform(for: corner, canvas: canvas)
        return local.copy(using: &transform) ?? local
    }

    public static func innerCurvePoints(
        for corner: ScreenCorner,
        radius: CGFloat,
        canvas: CGFloat = defaultCanvas,
        samplesPerSegment: Int = 20
    ) -> [CGPoint] {
        guard canvas > 0 else { return [] }
        let canvas = max(canvas, 1)
        let radius = min(max(radius, minimumPathRadius), canvas)
        let samples = max(samplesPerSegment, 1)

        let start = CGPoint(x: radius, y: 0)
        let first = scaled(firstCurvePoint, by: radius)
        let second = scaled(secondCurvePoint, by: radius)
        let end = CGPoint(x: 0, y: radius)

        var local: [CGPoint] = [start]
        appendCubic(
            from: start,
            control1: scaled(firstCurveControl, by: radius),
            control2: scaled(secondCurveControl, by: radius),
            to: first,
            samples: samples,
            into: &local
        )
        appendCubic(
            from: first,
            control1: scaled(thirdCurveControl, by: radius),
            control2: scaled(fourthCurveControl, by: radius),
            to: second,
            samples: samples,
            into: &local
        )
        appendCubic(
            from: second,
            control1: scaled(fifthCurveControl, by: radius),
            control2: scaled(sixthCurveControl, by: radius),
            to: end,
            samples: samples,
            into: &local
        )

        let transform = transform(for: corner, canvas: canvas)
        return local.map { $0.applying(transform) }
    }

    private static func appendCubic(
        from start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        to end: CGPoint,
        samples: Int,
        into points: inout [CGPoint]
    ) {
        for index in 1...samples {
            let t = CGFloat(index) / CGFloat(samples)
            let inverse = 1 - t
            let point = CGPoint(
                x: inverse * inverse * inverse * start.x
                    + 3 * inverse * inverse * t * control1.x
                    + 3 * inverse * t * t * control2.x
                    + t * t * t * end.x,
                y: inverse * inverse * inverse * start.y
                    + 3 * inverse * inverse * t * control1.y
                    + 3 * inverse * t * t * control2.y
                    + t * t * t * end.y
            )
            points.append(point)
        }
    }

    private static func scaled(_ point: CGPoint, by radius: CGFloat) -> CGPoint {
        CGPoint(x: point.x * radius, y: point.y * radius)
    }

    private static func transform(
        for corner: ScreenCorner,
        canvas: CGFloat
    ) -> CGAffineTransform {
        switch corner {
        case .topLeft:
            CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: canvas)
        case .topRight:
            CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: canvas, ty: canvas)
        case .bottomLeft:
            CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
        case .bottomRight:
            CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: canvas, ty: 0)
        }
    }
}
