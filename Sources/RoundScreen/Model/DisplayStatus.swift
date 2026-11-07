import CoreGraphics
import Foundation
import RoundScreenCore

struct DisplayStatus: Identifiable, Equatable {
    let id: String
    let name: String
    let corners: CornerStates
    let radii: CornerRadiusSet

    var stateLabel: String {
        if corners.isFullscreen {
            return "全屏 · 已隐藏"
        }
        if corners.isUniform {
            return corners.topLeft == .maximized ? "最大化" : "正常"
        }
        return "混合"
    }

    var symbolName: String {
        if corners.isFullscreen {
            return "arrow.up.left.and.arrow.down.right"
        }
        if corners.isUniform {
            return corners.topLeft == .maximized
                ? "rectangle.inset.filled"
                : "rectangle"
        }
        return "square.split.2x2"
    }

    var menuDescription: String {
        if corners.isFullscreen {
            return "\(name) · 全屏 · 已隐藏"
        }
        if corners.isUniform {
            return "\(name) · \(stateLabel) · \(Int(radii.topLeft.rounded())) pt"
        }
        return "\(name) · 左\(Int(radii.topLeft.rounded()))/\(Int(radii.bottomLeft.rounded())) · 右\(Int(radii.topRight.rounded()))/\(Int(radii.bottomRight.rounded()))"
    }

    var radiusLabel: String {
        let values = [
            radii.topLeft,
            radii.topRight,
            radii.bottomLeft,
            radii.bottomRight,
        ]
        let minimum = Int(values.min()?.rounded() ?? 0)
        let maximum = Int(values.max()?.rounded() ?? 0)
        return minimum == maximum ? "\(minimum) pt" : "\(minimum)–\(maximum) pt"
    }
}
