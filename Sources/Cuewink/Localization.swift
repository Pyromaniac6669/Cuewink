import Foundation

enum InterfaceLanguage: CaseIterable {
    case simplifiedChinese, english

    var locale: Locale { Locale(identifier: self == .simplifiedChinese ? "zh_Hans" : "en") }
}

enum LanguagePreference: Int, CaseIterable {
    case system, simplifiedChinese, english

    func resolve(preferredLanguages: [String] = Locale.preferredLanguages) -> InterfaceLanguage {
        switch self {
        case .simplifiedChinese: return .simplifiedChinese
        case .english: return .english
        case .system:
            for identifier in preferredLanguages {
                switch identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first {
                case "zh": return .simplifiedChinese
                case "en": return .english
                default: continue
                }
            }
            return .english
        }
    }

    func title(in language: InterfaceLanguage) -> String {
        switch self {
        case .system: return LocalizedText.followSystem.string(in: language)
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

// 使用穷举的文案键集中管理两种语言，避免缺失翻译或依赖运行时资源路径。
enum LocalizedText: CaseIterable {
    case missingMenuIcon, statusTooltip, running, feedbackDisabled, settings, closeWindow, quit
    case settingsTitle, screenPosition, general, display, interfaceLanguage, followSystem
    case launchAtLogin, clipboardAlerts, capsLockAlerts, sound, audition, openSystemSettings
    case duration, size, backgroundOpacity, short, medium, long, small, mediumSize, large, seconds, autosave
    case loginEnableFailed, loginDisableFailed, loginApproval, loginUnconfirmed
    case clipboardUpdated, capsLockOn, capsLockOff
    case topLeft, topCenter, topRight, centerLeft, center, centerRight, bottomLeft, bottomCenter, bottomRight

    func string(in language: InterfaceLanguage) -> String {
        let pair: (String, String)
        switch self {
        case .missingMenuIcon: pair = ("Cuewink 菜单栏图标资源缺失，请重新构建应用。", "Cuewink’s menu bar icon is missing. Please rebuild the app.")
        case .statusTooltip: pair = ("Cuewink · 剪贴板与大写锁定提示", "Cuewink · Clipboard and Caps Lock alerts")
        case .running: pair = ("Cuewink · 运行中", "Cuewink · Running")
        case .feedbackDisabled: pair = ("Cuewink · 提示已关闭", "Cuewink · Alerts off")
        case .settings: pair = ("设置…", "Settings…")
        case .closeWindow: pair = ("关闭窗口", "Close Window")
        case .quit: pair = ("退出 Cuewink", "Quit Cuewink")
        case .settingsTitle: pair = ("Cuewink 设置", "Cuewink Settings")
        case .screenPosition: pair = ("屏幕显示位置", "Screen position")
        case .general: pair = ("通用", "General")
        case .display: pair = ("显示", "Display")
        case .interfaceLanguage: pair = ("界面语言", "Language")
        case .followSystem: pair = ("跟随系统", "Follow System")
        case .launchAtLogin: pair = ("登录时启动", "Launch at login")
        case .clipboardAlerts: pair = ("剪贴板更新提示", "Clipboard alerts")
        case .capsLockAlerts: pair = ("大写锁定提示", "Caps Lock alerts")
        case .sound: pair = ("提示音", "Sound")
        case .audition: pair = ("试听", "Play")
        case .openSystemSettings: pair = ("前往系统设置", "Open System Settings")
        case .duration: pair = ("显示时长", "Duration")
        case .size: pair = ("浮层尺寸", "Toast size")
        case .backgroundOpacity: pair = ("背景不透明度", "Background opacity")
        case .short: pair = ("短", "Short")
        case .medium: pair = ("中", "Medium")
        case .long: pair = ("长", "Long")
        case .small: pair = ("小", "Small")
        case .mediumSize: pair = ("中", "Medium")
        case .large: pair = ("大", "Large")
        case .seconds: pair = ("秒", "s")
        case .autosave: pair = ("设置自动保存", "Settings are saved automatically")
        case .loginEnableFailed: pair = ("未能开启登录时启动，请重试。", "Could not enable launch at login. Please try again.")
        case .loginDisableFailed: pair = ("未能关闭登录时启动，请重试。", "Could not disable launch at login. Please try again.")
        case .loginApproval: pair = ("需要在系统设置中允许 Cuewink 登录时启动。", "Allow Cuewink to launch at login in System Settings.")
        case .loginUnconfirmed: pair = ("暂时无法获取登录启动状态。", "Launch at login status is currently unavailable.")
        case .clipboardUpdated: pair = ("剪贴板已更新", "Clipboard updated")
        case .capsLockOn: pair = ("大写锁定已开启", "Caps Lock on")
        case .capsLockOff: pair = ("大写锁定已关闭", "Caps Lock off")
        case .topLeft: pair = ("左上角", "Top left")
        case .topCenter: pair = ("顶部居中", "Top center")
        case .topRight: pair = ("右上角", "Top right")
        case .centerLeft: pair = ("左侧居中", "Center left")
        case .center: pair = ("屏幕中央", "Center")
        case .centerRight: pair = ("右侧居中", "Center right")
        case .bottomLeft: pair = ("左下角", "Bottom left")
        case .bottomCenter: pair = ("底部居中", "Bottom center")
        case .bottomRight: pair = ("右下角", "Bottom right")
        }
        return language == .simplifiedChinese ? pair.0 : pair.1
    }
}
