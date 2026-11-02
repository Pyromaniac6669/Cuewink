import AppKit

enum ToastPosition: Int, CaseIterable {
    case topLeft, topCenter, topRight, centerLeft, center, centerRight, bottomLeft, bottomCenter, bottomRight

    var title: String {
        ["左上角", "顶部居中", "右上角", "左侧居中", "屏幕中央", "右侧居中", "左下角", "底部居中", "右下角"][rawValue]
    }

    func frame(size: CGFloat, in area: NSRect) -> NSRect {
        let margin: CGFloat = 32
        let x = [area.minX + margin, area.midX - size / 2, area.maxX - size - margin][rawValue % 3]
        let y = [area.maxY - size - margin, area.midY - size / 2, area.minY + margin][rawValue / 3]
        return NSRect(
            x: min(max(x, area.minX), max(area.minX, area.maxX - size)),
            y: min(max(y, area.minY), max(area.minY, area.maxY - size)), width: size, height: size
        )
    }
}

enum ToastDuration: Int, CaseIterable {
    case short, medium, long
    var seconds: TimeInterval { [0.6, 1, 1.6][rawValue] }
}

enum ToastSize: Int, CaseIterable {
    case small, medium, large
    var points: CGFloat { [160, 192, 240][rawValue] }
}

struct Preferences: Equatable {
    var clipboardEnabled = true
    var capsLockEnabled = true
    var soundEnabled = false
    var position = ToastPosition.bottomCenter
    var duration = ToastDuration.medium
    var size = ToastSize.medium
    var backgroundOpacity = 0.85

    func allows(_ feedback: Feedback) -> Bool {
        switch feedback {
        case .clipboardUpdated: return clipboardEnabled
        case .capsLock: return capsLockEnabled
        }
    }
}

final class PreferencesStore {
    private let defaults: UserDefaults
    var onChange: ((Preferences) -> Void)?
    var value: Preferences {
        didSet {
            defaults.set(value.clipboardEnabled, forKey: "clipboardEnabled")
            defaults.set(value.capsLockEnabled, forKey: "capsLockEnabled")
            defaults.set(value.soundEnabled, forKey: "soundEnabled")
            defaults.set(value.position.rawValue, forKey: "toastPosition")
            defaults.set(value.duration.rawValue, forKey: "toastDuration")
            defaults.set(value.size.rawValue, forKey: "toastSize")
            defaults.set(value.backgroundOpacity, forKey: "backgroundOpacity")
            onChange?(value)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "clipboardEnabled": true, "capsLockEnabled": true, "soundEnabled": false,
            "toastPosition": ToastPosition.bottomCenter.rawValue,
            "toastDuration": ToastDuration.medium.rawValue, "toastSize": ToastSize.medium.rawValue,
            "backgroundOpacity": 0.85
        ])
        let opacity = defaults.double(forKey: "backgroundOpacity")
        value = Preferences(
            clipboardEnabled: defaults.bool(forKey: "clipboardEnabled"),
            capsLockEnabled: defaults.bool(forKey: "capsLockEnabled"),
            soundEnabled: defaults.bool(forKey: "soundEnabled"),
            position: ToastPosition(rawValue: defaults.integer(forKey: "toastPosition")) ?? .bottomCenter,
            duration: ToastDuration(rawValue: defaults.integer(forKey: "toastDuration")) ?? .medium,
            size: ToastSize(rawValue: defaults.integer(forKey: "toastSize")) ?? .medium,
            backgroundOpacity: opacity.isFinite ? min(1, max(0.4, opacity)) : 0.85
        )
    }
}
