import CoreGraphics
import Foundation
import RoundScreenCore

struct RoundScreenSettings: Codable, Equatable {
    var isEnabled: Bool = true
    var normalRadius: Double = 20
    var maximizedRadius: Double = 14

    var radiusProfile: CornerRadiusProfile {
        CornerRadiusProfile(
            normal: CGFloat(normalRadius),
            maximized: CGFloat(maximizedRadius),
            fullscreen: 0
        )
    }

    func clamped() -> RoundScreenSettings {
        var copy = self
        copy.normalRadius = min(max(copy.normalRadius, 0), 60)
        copy.maximizedRadius = min(max(copy.maximizedRadius, 0), 60)
        return copy
    }
}

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = ["roundscreen", "settings", "v3"].joined(separator: ".")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> RoundScreenSettings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(RoundScreenSettings.self, from: data)
        else {
            return RoundScreenSettings()
        }
        return settings.clamped()
    }

    func save(_ settings: RoundScreenSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
