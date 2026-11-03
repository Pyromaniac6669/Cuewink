import AppKit

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}

private final class MemoryDefaults: UserDefaults {
    private var saved: [String: Any]
    private var registered: [String: Any] = [:]
    init(storage: [String: Any] = [:]) {
        saved = storage
        super.init(suiteName: "local.cuewink.memory-tests")!
    }
    override func register(defaults: [String: Any]) { registered.merge(defaults) { existing, _ in existing } }
    override func set(_ value: Any?, forKey key: String) { saved[key] = value }
    override func bool(forKey key: String) -> Bool { (saved[key] ?? registered[key]) as? Bool ?? false }
    override func integer(forKey key: String) -> Int { (saved[key] ?? registered[key]) as? Int ?? 0 }
    override func double(forKey key: String) -> Double { (saved[key] ?? registered[key]) as? Double ?? 0 }
}

private final class TestLoginItem: LoginItemManaging {
    var status = LoginItemStatus.disabled
    var changes: [Bool] = []
    var fails = false
    func setEnabled(_ enabled: Bool) throws {
        changes.append(enabled)
        if fails { throw NSError(domain: "local.cuewink.tests", code: 1, userInfo: [NSLocalizedDescriptionKey: "模拟登录项注册失败"]) }
        status = enabled ? .enabled : .disabled
    }
    func openSystemSettings() {}
}

@main
enum PrototypeTests {
    static func main() {
        do {
            try runTests()
        } catch {
            fputs("验证失败：\(error)\n", stderr)
            exit(1)
        }
    }

    static func runTests() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let localizationTests: [(String, () throws -> Void)] = [
            ("语言匹配、回退和偏好保存", languagePreferences),
            ("双菜单文字、状态与快捷键同步切换", localizedMenus),
            ("语言切换保留控件、登录错误并适配英文布局", localizedSettings),
            ("中英文浮层三档布局与切换不延长计时", localizedToast)
        ]
        let allTests: [(String, () throws -> Void)] = [
            ("启动基线与无更新保持安静", baseline),
            ("稳定更新只提示一次", stableUpdate),
            ("清空不提示，之后写入可提示", emptyThenWrite),
            ("重复内容的新版本不被去重", repeatedWrites),
            ("分步写入等待最新版本稳定", stagedWrite),
            ("同一版本延迟出现内容类型仍可提示", delayedTypes),
            ("只有大写锁定状态变化才提示", capsLock),
            ("休眠重建基线不补放旧提示", reset),
            ("独立剪贴板真实写入与计时轮询", pasteboardIntegration),
            ("浮层不抢焦点且刷新消失时间", toastIntegration),
            ("浮层完整窗口没有额外亮边", toastWindowEdge),
            ("偏好保存、重新读取和无效值边界", preferences),
            ("九方位在负坐标屏幕内正确定位", positions),
            ("浮层尺寸、背景透明度和开关即时生效", configurableToast),
            ("设置窗口交互、复用和登录项状态反馈", settingsWindow)
        ] + localizationTests + [
            ("登录启动状态与行内说明回归", loginStatusFeedback)
        ]
        let tests = CommandLine.arguments.contains("--localization") ? localizationTests :
            CommandLine.arguments.contains("--login-status") ? Array(allTests.suffix(1)) : allTests
        for (name, test) in tests {
            try test()
            print("通过：\(name)")
        }
        print("全部 \(tests.count) 项验证通过")
    }

    static func baseline() throws {
        var tracker = ChangeTracker()
        try expect(tracker.sample(count: 10, capsLock: true, now: 0) { true }.isEmpty, "启动不能提示")
        try expect(tracker.sample(count: 10, capsLock: true, now: 10) { true }.isEmpty, "无更新不能提示")
    }

    static func stableUpdate() throws {
        var tracker = ChangeTracker()
        _ = tracker.sample(count: 1, capsLock: false, now: 0) { true }
        try expect(tracker.sample(count: 2, capsLock: false, now: 1) { true }.isEmpty, "新版本需要稳定窗口")
        try expect(tracker.sample(count: 2, capsLock: false, now: 1.2) { true } == [.clipboardUpdated], "稳定后应提示")
        try expect(tracker.sample(count: 2, capsLock: false, now: 2) { true }.isEmpty, "同版本不能重复提示")
    }

    static func emptyThenWrite() throws {
        var tracker = ChangeTracker()
        _ = tracker.sample(count: 1, capsLock: false, now: 0) { true }
        _ = tracker.sample(count: 2, capsLock: false, now: 1) { false }
        try expect(tracker.sample(count: 2, capsLock: false, now: 1.2) { false }.isEmpty, "清空不能提示")
        _ = tracker.sample(count: 3, capsLock: false, now: 2) { true }
        try expect(tracker.sample(count: 3, capsLock: false, now: 2.2) { true } == [.clipboardUpdated], "清空后的新写入应提示")
    }

    static func repeatedWrites() throws {
        var tracker = ChangeTracker()
        _ = tracker.sample(count: 1, capsLock: false, now: 0) { true }
        for count in 2...3 {
            let now = Double(count)
            _ = tracker.sample(count: count, capsLock: false, now: now) { true }
            try expect(tracker.sample(count: count, capsLock: false, now: now + 0.2) { true } == [.clipboardUpdated], "每个新版本都应反馈")
        }
    }

    static func stagedWrite() throws {
        var tracker = ChangeTracker()
        _ = tracker.sample(count: 1, capsLock: false, now: 0) { true }
        _ = tracker.sample(count: 2, capsLock: false, now: 1) { false }
        _ = tracker.sample(count: 3, capsLock: false, now: 1.05) { true }
        try expect(tracker.sample(count: 3, capsLock: false, now: 1.1) { true }.isEmpty, "不能沿用旧版本的计时")
        try expect(tracker.sample(count: 3, capsLock: false, now: 1.2) { true } == [.clipboardUpdated], "只提示最终稳定版本")
    }

    static func capsLock() throws {
        var tracker = ChangeTracker()
        _ = tracker.sample(count: 1, capsLock: false, now: 0) { true }
        try expect(tracker.sample(count: 1, capsLock: true, now: 1) { true } == [.capsLock(true)], "开启应提示")
        try expect(tracker.sample(count: 1, capsLock: true, now: 2) { true }.isEmpty, "锁定未变不能提示")
        try expect(tracker.sample(count: 1, capsLock: false, now: 3) { true } == [.capsLock(false)], "关闭应提示")
    }

    static func delayedTypes() throws {
        var tracker = ChangeTracker()
        _ = tracker.sample(count: 1, capsLock: false, now: 0) { true }
        _ = tracker.sample(count: 2, capsLock: false, now: 1) { false }
        try expect(tracker.sample(count: 2, capsLock: false, now: 1.2) { false }.isEmpty, "清空后不能提前提示")
        try expect(tracker.sample(count: 2, capsLock: false, now: 1.4) { true } == [.clipboardUpdated], "同一所有者延迟声明类型时不能漏掉更新")
        try expect(tracker.sample(count: 2, capsLock: false, now: 1.6) { true }.isEmpty, "延迟写入仍只能提示一次")
    }

    static func reset() throws {
        var tracker = ChangeTracker()
        _ = tracker.sample(count: 1, capsLock: false, now: 0) { true }
        _ = tracker.sample(count: 2, capsLock: false, now: 1) { true }
        tracker.reset()
        try expect(tracker.sample(count: 3, capsLock: true, now: 10) { true }.isEmpty, "恢复后先建立新基线")
        try expect(tracker.sample(count: 3, capsLock: true, now: 11) { true }.isEmpty, "不能补放旧提示")
    }

    static func spin(_ duration: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
    }

    static func pasteboardIntegration() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        var events: [Feedback] = []
        var writeStartedAt: TimeInterval?
        var latencies: [TimeInterval] = []
        let monitor = StateMonitor(pasteboard: pasteboard, readCapsLock: { false }) {
            events.append($0)
            if let startedAt = writeStartedAt {
                latencies.append(ProcessInfo.processInfo.systemUptime - startedAt)
                writeStartedAt = nil
            }
        }
        monitor.start()
        defer { monitor.stop() }
        for index in 1...2 {
            pasteboard.clearContents()
            try expect(pasteboard.setString("Cuewink 测试内容", forType: .string), "测试剪贴板写入失败")
            writeStartedAt = ProcessInfo.processInfo.systemUptime
            spin(0.45)
            try expect(events.count == index && events.last == .clipboardUpdated, "真实重复写入应各提示一次")
        }
        pasteboard.clearContents()
        spin(0.45)
        try expect(events.count == 2, "清空真实测试剪贴板不应提示")
        writeStartedAt = ProcessInfo.processInfo.systemUptime
        try expect(pasteboard.setString("延迟写入", forType: .string), "延迟测试写入失败")
        spin(0.45)
        try expect(events.count == 3, "先清空再延迟写入也应提示")
        monitor.stop()
        pasteboard.setString("停止后的写入", forType: .string)
        spin(0.3)
        try expect(events.count == 3, "停止后不能继续轮询")
        print("测试剪贴板检测耗时（毫秒）：\(latencies.map { Int($0 * 1000) })")
    }

    static func toastIntegration() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        guard let screen = NSScreen.main else { throw TestFailure(description: "无法取得屏幕，桌面验证未执行") }
        guard let activePID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            throw TestFailure(description: "无法识别前台应用，焦点保持验证未执行")
        }
        let panel = ToastPanel(preferences: Preferences(duration: .short, language: .simplifiedChinese))
        defer { panel.hide() }
        try expect(!panel.canBecomeKey && !panel.canBecomeMain && panel.ignoresMouseEvents, "浮层必须不接收焦点和点击")
        panel.show(.clipboardUpdated, on: screen)
        try expect(panel.isVisible, "浮层应可见")
        try expect(abs(panel.frame.midX - screen.visibleFrame.midX) < 1, "浮层应水平居中")
        try checkToastContent(panel, feedback: .clipboardUpdated)
        spin(0.36)
        panel.show(.capsLock(true), on: screen)
        try checkToastContent(panel, feedback: .capsLock(true))
        spin(0.36)
        try expect(panel.isVisible, "连续触发必须重置消失时间")
        try expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == activePID, "浮层不能激活自身或切走前台应用")
        spin(0.32)
        try expect(!panel.isVisible, "刷新后的浮层应自动消失")
        panel.show(.capsLock(false), on: screen)
        try checkToastContent(panel, feedback: .capsLock(false))
        print("桌面验证屏幕数量：\(NSScreen.screens.count)")
    }

    static func toastWindowEdge() throws {
        let panel = ToastPanel()
        defer { panel.hide() }
        panel.show(.clipboardUpdated)
        spin(0.15)
        // 保留窗口框架效果；裁去框架会漏掉系统阴影附带的细线。
        guard let capture = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(panel.windowNumber), .bestResolution) else {
            throw TestFailure(description: "无法捕获完整测试浮层，亮边验证未执行")
        }
        let bitmap = NSBitmapImageRep(cgImage: capture)
        let column = bitmap.pixelsWide / 2
        let colors = (0..<bitmap.pixelsHigh).map {
            bitmap.colorAt(x: column, y: $0)!.usingColorSpace(.sRGB)!
        }
        // 只从图标上方的背景取样，避免清晰文字的实色像素被误当成窗口外缘。
        let maximumAlpha = colors.prefix(bitmap.pixelsHigh / 6).map(\.alphaComponent).max() ?? 0
        guard maximumAlpha > 0.1,
              let edge = colors.firstIndex(where: { $0.alphaComponent > maximumAlpha * 0.98 }), edge + 10 <= colors.count else {
            throw TestFailure(description: "无法识别浮层的实色边缘")
        }
        func luminance(_ color: NSColor) -> CGFloat {
            0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
        }
        let rim = colors[edge..<edge + 2].map(luminance).max()!
        let interior = colors[edge + 4..<edge + 10].map(luminance).reduce(0, +) / 6
        try expect(rim - interior < 0.06, "完整窗口存在额外亮边，边缘亮度突增 \(rim - interior)")
    }

    static func preferences() throws {
        let defaults = MemoryDefaults()
        let store = PreferencesStore(defaults: defaults)
        try expect(store.value == Preferences(), "全新偏好必须使用已确认的默认值")
        var changes = 0
        store.onChange = { _ in changes += 1 }
        var value = store.value
        value.clipboardEnabled = false
        value.capsLockEnabled = false
        value.soundEnabled = true
        value.position = .topRight
        value.duration = .long
        value.size = .large
        value.backgroundOpacity = 0.4
        store.value = value
        try expect(changes == 1 && PreferencesStore(defaults: defaults).value == value, "全部偏好必须保存、重新读取并发送变更")
        try expect(!value.allows(.clipboardUpdated) && !value.allows(.capsLock(true)) && !value.allows(.capsLock(false)), "关闭的提示类型不能因声音开启而放行")
        value.capsLockEnabled = true
        try expect(value.allows(.capsLock(true)) && value.allows(.capsLock(false)) && !value.allows(.clipboardUpdated), "两类开关必须独立，大写开启与关闭共用同一开关")
        let invalid = PreferencesStore(defaults: MemoryDefaults(storage: ["toastPosition": -1, "toastDuration": 99, "toastSize": 99, "backgroundOpacity": -1.0]))
        try expect(invalid.value.position == .bottomCenter && invalid.value.duration == .medium && invalid.value.size == .medium, "无效档位应使用默认值")
        try expect(invalid.value.backgroundOpacity == 0.4, "背景不透明度不能低于范围下限")
        try expect(PreferencesStore(defaults: MemoryDefaults(storage: ["backgroundOpacity": 2.0])).value.backgroundOpacity == 1, "背景不透明度不能超过范围上限")
    }

    static func positions() throws {
        let area = NSRect(x: -1520, y: 200, width: 1440, height: 900)
        for size in ToastSize.allCases {
            let frames = ToastPosition.allCases.map { $0.frame(size: size.points, in: area) }
            try expect(frames.allSatisfy(area.contains), "九个位置在每种尺寸下都必须位于目标可用区域内")
            try expect(Set(frames.map { "\($0.origin.x),\($0.origin.y)" }).count == 9, "九个方位必须各不相同")
        }
        try expect(ToastPosition.topLeft.frame(size: 192, in: area).origin == NSPoint(x: -1488, y: 876), "左上角必须保留边距并支持副屏负坐标")
        try expect(ToastPosition.bottomRight.frame(size: 192, in: area).origin == NSPoint(x: -304, y: 232), "右下角必须保留底边和右边边距")
        let center = ToastPosition.center.frame(size: 192, in: area)
        try expect(center.midX == area.midX && center.midY == area.midY, "中央位置必须沿两轴居中")
    }

    static func configurableToast() throws {
        let panel = ToastPanel()
        defer { panel.hide() }
        guard let screen = NSScreen.main else { throw TestFailure(description: "无法取得测试屏幕") }
        var preferences = Preferences(language: .simplifiedChinese)
        for size in ToastSize.allCases {
            preferences.size = size
            preferences.backgroundOpacity = 0.4
            preferences.position = .topRight
            panel.apply(preferences)
            for feedback in [Feedback.clipboardUpdated, .capsLock(true), .capsLock(false)] {
                panel.show(feedback, on: screen)
                try checkToastContent(panel, feedback: feedback)
            }
            try expect(panel.frame.size == NSSize(width: size.points, height: size.points), "每个档位必须使用确认的尺寸")
            try expect(panel.frame.maxX == screen.visibleFrame.maxX - 32 && panel.frame.maxY == screen.visibleFrame.maxY - 32, "配置的方位必须用于实际窗口")
        }
        guard let content = panel.contentView,
              let background = content.subviews.first(where: { $0 is NSVisualEffectView }) else {
            throw TestFailure(description: "浮层缺少独立背景")
        }
        try expect(background.alphaValue == 0.4 && content.alphaValue == 1, "背景不透明度不能改变整个窗口")
        try expect(content.subviews.filter { $0 is NSTextField || $0 is NSImageView }.allSatisfy { $0.alphaValue == 1 }, "图标和文字必须保持清晰")
        preferences.capsLockEnabled = false
        panel.apply(preferences)
        try expect(!panel.isVisible, "关闭当前提示类别必须立即隐藏浮层")
        panel.show(.capsLock(true), on: screen)
        try expect(!panel.isVisible, "关闭类别后不能再次显示对应浮层")
        panel.show(.clipboardUpdated, on: screen)
        try expect(panel.isVisible, "另一种提示仍可正常显示")
    }

    static func settingsWindow() throws {
        let store = PreferencesStore(defaults: MemoryDefaults(storage: ["interfaceLanguage": LanguagePreference.simplifiedChinese.rawValue]))
        let login = TestLoginItem()
        var auditions = 0
        let controller = SettingsWindowController(store: store, loginItem: login) { auditions += 1 }
        guard let window = controller.window, let content = window.contentView else { throw TestFailure(description: "设置窗口未创建") }
        controller.showWindow(nil)
        defer { window.close() }
        spin(0.15)
        content.layoutSubtreeIfNeeded()
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let views = descendants(content)
        func capture(_ name: String) throws {
            if let directory = ProcessInfo.processInfo.environment["CUEWINK_TEST_OUTPUT"],
               let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), .bestResolution),
               let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
            }
        }
        guard let picker = views.compactMap({ $0 as? ScreenPositionPicker }).first else { throw TestFailure(description: "缺少屏幕位置选择区域") }
        try expect(picker.frame.width > 400 && picker.frame.height > 200, "屏幕示意必须以完整宽度显示")
        try expect(content.bounds.contains(picker.convert(picker.bounds, to: content)), "首次打开时屏幕位置区域应完整可见")
        try capture("settings-window.png")
        func named<T: NSView>(_ name: String, as type: T.Type) throws -> T {
            guard let view = views.compactMap({ $0 as? T }).first(where: { $0.accessibilityLabel() == name }) else { throw TestFailure(description: "缺少设置控件：\(name)") }
            return view
        }
        func send(_ control: NSControl) { if let action = control.action { NSApp.sendAction(action, to: control.target, from: control) } }
        try expect(window.canBecomeKey && !window.ignoresMouseEvents, "设置窗口必须能够正常交互")
        try expect(login.changes.isEmpty, "打开设置窗口不能注册登录项")
        let position = try named("顶部居中", as: NSButton.self)
        position.performClick(nil)
        try expect(store.value.position == .topCenter, "九宫格必须保存所选方位")
        try expect(views.compactMap { $0 as? NSButton }.filter { button in ToastPosition.allCases.contains { $0.title(in: .simplifiedChinese) == button.accessibilityLabel() } }.count == 9, "九宫格必须有九个可操作位置")
        let size = try named("浮层尺寸", as: NSSegmentedControl.self)
        size.selectedSegment = ToastSize.large.rawValue
        send(size)
        try expect(store.value.size == .large, "尺寸控件必须更新偏好")
        let duration = try named("显示时长", as: NSSegmentedControl.self)
        duration.selectedSegment = ToastDuration.long.rawValue
        send(duration)
        let opacity = try named("背景不透明度", as: NSSlider.self)
        opacity.doubleValue = 40
        send(opacity)
        try expect(store.value.duration == .long && store.value.backgroundOpacity == 0.4, "时长和不透明度必须即时保存")
        let clipboard = try named("剪贴板更新提示", as: NSSwitch.self)
        clipboard.state = .off
        send(clipboard)
        try expect(!store.value.clipboardEnabled && store.value.capsLockEnabled, "关闭剪贴板提示不能连带关闭大写锁定")
        if let button = views.compactMap({ $0 as? NSButton }).first(where: { $0.title == "试听" }) { button.performClick(nil) }
        try expect(auditions == 1 && !store.value.soundEnabled, "试听不应改变提示音开关")
        let loginSwitch = try named("登录时启动", as: NSSwitch.self)
        loginSwitch.state = .on
        send(loginSwitch)
        try expect(login.changes == [true] && loginSwitch.state == .on, "登录项仅在明确点击后修改并反映实际状态")
        login.status = .requiresApproval
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: window))
        try expect(views.compactMap { $0 as? NSTextField }.contains { $0.stringValue.contains("系统设置中允许") && !$0.isHidden }, "待批准状态不能冒充已启用")
        login.fails = true
        loginSwitch.state = .off
        send(loginSwitch)
        try expect(loginSwitch.state == .on, "登录项修改失败后开关必须恢复真实状态")
        if let sheet = window.attachedSheet { window.endSheet(sheet); sheet.close() }
        spin(0.15)
        try capture("settings-window-login-approval.png")
        window.close()
        controller.showWindow(nil)
        try expect(controller.window === window && window.isVisible, "关闭后必须复用同一设置窗口")
    }

    static func loginStatusFeedback() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let login = TestLoginItem()
        login.status = .unconfirmed
        let controller = SettingsWindowController(store: PreferencesStore(defaults: MemoryDefaults(storage: ["interfaceLanguage": LanguagePreference.simplifiedChinese.rawValue])), loginItem: login) {}
        guard let window = controller.window, let content = window.contentView else { throw TestFailure(description: "设置窗口未创建") }
        controller.showWindow(nil)
        defer { window.close() }
        spin(0.1)
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        func notice() throws -> NSTextField {
            guard let view = descendants(content).compactMap({ $0 as? NSTextField }).first(where: { $0.identifier?.rawValue == "loginNotice" }) else {
                throw TestFailure(description: "登录启动说明没有明确归属于该设置项")
            }
            return view
        }
        func refresh() { controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification, object: window)); content.layoutSubtreeIfNeeded() }
        func visible(_ view: NSView) -> Bool { !view.isHidden && (view.superview.map(visible) ?? true) }
        func capture(_ name: String) throws {
            spin(0.15)
            if let directory = ProcessInfo.processInfo.environment["CUEWINK_TEST_OUTPUT"],
               let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), .bestResolution),
               let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
            }
        }
        guard let toggle = descendants(content).compactMap({ $0 as? NSSwitch }).first(where: { $0.accessibilityLabel() == "登录时启动" }) else {
            throw TestFailure(description: "缺少登录启动开关")
        }
        try expect(login.changes.isEmpty, "打开窗口只允许查询，不能注册登录项")
        try expect(toggle.isEnabled && toggle.state == .off, "服务查询未找到记录不能禁用用户主动开启登录启动的操作")
        let unknownNotice = try notice()
        try expect(unknownNotice.stringValue.contains("登录启动状态") && !unknownNotice.stringValue.contains("打包"), "状态未知时不能诊断为应用未打包")
        var parent = unknownNotice.superview
        while parent != nil && parent?.identifier?.rawValue != "loginSettingRow" { parent = parent?.superview }
        guard let loginRow = parent else { throw TestFailure(description: "登录启动说明必须嵌入所属设置行") }
        try expect(toggle.isDescendant(of: loginRow), "说明与开关必须位于同一设置行")
        if let clipboard = descendants(content).compactMap({ $0 as? NSSwitch }).first(where: { $0.accessibilityLabel() == "剪贴板更新提示" }) {
            try expect(!clipboard.isDescendant(of: loginRow), "不能把整个通用分组当成登录启动设置行")
        }
        toggle.state = .on
        NSApp.sendAction(toggle.action!, to: toggle.target, from: toggle)
        try expect(login.changes == [true] && toggle.state == .on, "状态未确认时用户主动开启必须能到达注册接口")
        login.status = .disabled
        refresh()
        try expect(!visible(unknownNotice), "正常关闭时不能显示异常说明")
        login.status = .enabled
        refresh()
        try expect(!visible(unknownNotice) && toggle.state == .on, "正常开启时不能显示异常说明")
        login.status = .requiresApproval
        refresh()
        let pending = try notice()
        try expect(visible(pending) && pending.stringValue.contains("系统设置") && pending.stringValue.contains("登录时启动"), "待批准说明必须明确对象和下一步")
        guard let help = descendants(loginRow).compactMap({ $0 as? NSButton }).first(where: { $0.title == "前往系统设置" }) else {
            throw TestFailure(description: "系统设置入口必须在登录启动行内")
        }
        try expect(visible(help), "待批准时必须显示系统设置入口")
        login.status = .disabled
        login.fails = true
        refresh()
        toggle.state = .on
        NSApp.sendAction(toggle.action!, to: toggle.target, from: toggle)
        let failure = try notice()
        try expect(toggle.state == .off && visible(failure) && failure.stringValue.contains("未能开启登录时启动"), "开启失败必须在原设置行内说明并恢复真实状态")
        try expect(window.attachedSheet == nil, "登录启动操作失败不应再使用脱离设置行的弹窗")
        try expect(failure.toolTip?.contains("模拟登录项注册失败") == true, "操作失败应保留系统错误详情")
        login.status = .enabled
        toggle.state = .off
        NSApp.sendAction(toggle.action!, to: toggle.target, from: toggle)
        let disableFailure = try notice()
        try expect(toggle.state == .on && disableFailure.stringValue.contains("未能关闭登录时启动"), "关闭失败必须与开启失败区分")
        try capture("login-inline-error.png")
        login.status = .requiresApproval
        controller.present()
        refresh()
        let reopenedNotice = try notice()
        try expect(reopenedNotice.stringValue.contains("系统设置"), "重新打开设置应清除过期操作错误并显示当前系统状态")
        try capture("login-inline-feedback.png")
    }

    static func languagePreferences() throws {
        let cases: [([String], InterfaceLanguage)] = [
            (["zh-Hans-CN", "en"], .simplifiedChinese), (["zh-Hant-TW"], .simplifiedChinese),
            (["ZH_hant_HK"], .simplifiedChinese), (["en-GB", "zh-Hans"], .english),
            (["ja-JP", "zh-CN", "en-US"], .simplifiedChinese), (["ja", "en", "zh"], .english),
            (["fr", "de"], .english), ([], .english), (["", "zho", "english"], .english)
        ]
        for (preferred, expected) in cases {
            try expect(LanguagePreference.system.resolve(preferredLanguages: preferred) == expected, "系统首选语言必须按顺序匹配、中文变体归为简体、无匹配时使用英语：\(preferred)")
            try expect(LanguagePreference.simplifiedChinese.resolve(preferredLanguages: preferred) == .simplifiedChinese, "手动中文不受系统影响")
            try expect(LanguagePreference.english.resolve(preferredLanguages: preferred) == .english, "手动英语不受系统影响")
        }
        let defaults = MemoryDefaults()
        let store = PreferencesStore(defaults: defaults)
        try expect(store.value.language == .system, "默认语言偏好必须跟随系统")
        for language in LanguagePreference.allCases {
            store.value.language = language
            try expect(PreferencesStore(defaults: defaults).value.language == language, "重建偏好必须保留语言选择")
        }
        try expect(PreferencesStore(defaults: MemoryDefaults(storage: ["interfaceLanguage": 99])).value.language == .system, "无效语言值回退跟随系统")
    }

    static func localizedMenus() throws {
        let action = #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        let menus = ApplicationMenus(settingsTarget: NSApp, settingsAction: action)
        guard let application = menus.mainMenu.items.first?.submenu else { throw TestFailure(description: "缺少应用菜单") }
        for (preference, language) in [(LanguagePreference.english, InterfaceLanguage.english), (.simplifiedChinese, .simplifiedChinese)] {
            var value = Preferences(language: preference)
            menus.update(value)
            try expect(menus.statusMenu.items.first?.title == LocalizedText.running.string(in: language), "菜单状态必须同步翻译")
            for menu in [menus.statusMenu, application] {
                guard let settings = menu.items.first(where: { $0.keyEquivalent == "," }),
                      let quit = menu.items.first(where: { $0.keyEquivalent == "q" }) else { throw TestFailure(description: "缺少菜单快捷键") }
                try expect(settings.title == LocalizedText.settings.string(in: language) && settings.action == action && settings.target === NSApp, "设置文字更新时必须保留动作和快捷键")
                try expect(quit.title == LocalizedText.quit.string(in: language) && quit.action == #selector(NSApplication.terminate(_:)), "退出菜单必须同步翻译并保留动作")
            }
            try expect(application.items.first(where: { $0.keyEquivalent == "w" })?.title == LocalizedText.closeWindow.string(in: language), "关闭窗口快捷键必须保留")
            value.clipboardEnabled = false
            value.capsLockEnabled = false
            menus.update(value)
            try expect(menus.statusMenu.items.first?.title == LocalizedText.feedbackDisabled.string(in: language), "关闭提示后的状态也必须翻译")
        }
    }

    static func localizedSettings() throws {
        let defaults = MemoryDefaults(storage: ["interfaceLanguage": LanguagePreference.simplifiedChinese.rawValue])
        let store = PreferencesStore(defaults: defaults)
        let login = TestLoginItem()
        login.fails = true
        let controller = SettingsWindowController(store: store, loginItem: login) {}
        guard let window = controller.window, let content = window.contentView else { throw TestFailure(description: "设置窗口未创建") }
        controller.showWindow(nil)
        defer { window.close() }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let views = descendants(content)
        guard let popup = views.compactMap({ $0 as? NSPopUpButton }).first,
              let toggle = views.compactMap({ $0 as? NSSwitch }).first(where: { $0.accessibilityLabel() == "登录时启动" }),
              let notice = views.compactMap({ $0 as? NSTextField }).first(where: { $0.identifier?.rawValue == "loginNotice" }) else { throw TestFailure(description: "缺少语言或登录控件") }
        toggle.state = .on
        NSApp.sendAction(toggle.action!, to: toggle.target, from: toggle)
        let detail = notice.toolTip
        for (preference, language) in [(LanguagePreference.english, InterfaceLanguage.english), (.simplifiedChinese, .simplifiedChinese), (.system, LanguagePreference.system.resolve())] {
            popup.selectItem(withTag: preference.rawValue)
            NSApp.sendAction(popup.action!, to: popup.target, from: popup)
            spin(0.1)
            content.layoutSubtreeIfNeeded()
            try expect(window.title == LocalizedText.settingsTitle.string(in: language), "已打开窗口必须即时切换标题")
            try expect(popup.selectedItem?.tag == preference.rawValue && PreferencesStore(defaults: defaults).value.language == preference, "选择必须即时保存")
            try expect(popup.menu?.item(withTag: LanguagePreference.simplifiedChinese.rawValue)?.title == "简体中文" && popup.menu?.item(withTag: LanguagePreference.english.rawValue)?.title == "English", "语言自称必须保持固定")
            try expect(popup.menu?.item(withTag: LanguagePreference.system.rawValue)?.title == LocalizedText.followSystem.string(in: language), "跟随系统选项也必须翻译")
            try expect(views.count == descendants(content).count && popup === descendants(content).compactMap({ $0 as? NSPopUpButton }).first, "切换不应重建窗口控件")
            try expect(toggle.accessibilityLabel() == LocalizedText.launchAtLogin.string(in: language), "辅助功能标签必须同步切换")
            try expect(notice.stringValue == LocalizedText.loginEnableFailed.string(in: language) && notice.toolTip == detail, "切换应翻译错误说明并保留原始详情")
            for position in ToastPosition.allCases {
                try expect(views.compactMap({ $0 as? NSButton }).contains { $0.toolTip == position.title(in: language) && $0.accessibilityLabel() == position.title(in: language) }, "九方位标签与悬停提示必须全部切换")
            }
            let labels = views.compactMap { $0 as? NSTextField }
            for field in labels where !field.isHidden && field !== notice && !field.stringValue.isEmpty {
                try expect(field.intrinsicContentSize.width <= field.bounds.width + 1, "设置文字必须完整可见：\(field.stringValue)")
            }
            for segment in views.compactMap({ $0 as? NSSegmentedControl }) {
                try expect(segment.label(forSegment: 1) == LocalizedText.medium.string(in: language), "分段选项必须同步翻译")
            }
            if preference == .english {
                try expect(labels.allSatisfy { $0.stringValue.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) == nil }, "英语界面不能残留应用中文标签")
                if let directory = ProcessInfo.processInfo.environment["CUEWINK_TEST_OUTPUT"],
                   let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), .bestResolution),
                   let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("settings-english.png"))
                }
            }
        }
        try expect(login.changes == [true], "切换语言不能再次注册登录项")
        window.close()
        controller.present()
        try expect(controller.window === window && popup.selectedItem?.tag == LanguagePreference.system.rawValue, "重新打开窗口保留选择且复用窗口")
    }

    static func localizedToast() throws {
        let panel = ToastPanel()
        defer { panel.hide() }
        for (preference, language) in [(LanguagePreference.english, InterfaceLanguage.english), (.simplifiedChinese, .simplifiedChinese)] {
            for size in ToastSize.allCases {
                panel.apply(Preferences(size: size, language: preference))
                for feedback in [Feedback.clipboardUpdated, .capsLock(true), .capsLock(false)] {
                    panel.show(feedback)
                    try checkToastContent(panel, feedback: feedback, language: language)
                    try expect(panel.frame.size == NSSize(width: size.points, height: size.points), "语言和尺寸切换后必须保留指定方形尺寸")
                }
            }
        }
        var value = Preferences(duration: .short, language: .simplifiedChinese)
        panel.apply(value)
        panel.show(.clipboardUpdated)
        spin(0.35)
        value.language = .english
        panel.apply(value)
        try checkToastContent(panel, feedback: .clipboardUpdated, language: .english)
        try expect(panel.isVisible, "切换语言时浮层应继续可见")
        spin(0.35)
        try expect(!panel.isVisible, "只切换语言不能延长原定消失时间")
        panel.show(.capsLock(false))
        try checkToastContent(panel, feedback: .capsLock(false), language: .english)
    }

    static func checkToastContent(_ panel: ToastPanel, feedback: Feedback, language: InterfaceLanguage = .simplifiedChinese) throws {
        guard let content = panel.contentView,
              let icon = content.subviews.compactMap({ $0 as? NSImageView }).first,
              let label = content.subviews.compactMap({ $0 as? NSTextField }).first else {
            throw TestFailure(description: "浮层缺少图标或提示文字")
        }
        content.layoutSubtreeIfNeeded()
        try expect(abs(panel.frame.width - panel.frame.height) < 1, "浮层必须为正方形：\(panel.frame.size)，文案 \(label.stringValue)，自然宽度 \(label.intrinsicContentSize.width)")
        try expect(icon.image != nil && !icon.isHidden, "每种状态必须显示图标")
        try expect(label.stringValue == feedback.message(in: language), "连续切换时必须更新文案")
        try expect(content.bounds.contains(icon.frame) && content.bounds.contains(label.frame), "图标和文字不能超出浮层")
        try expect(icon.frame.minY > label.frame.maxY, "图标应位于文字上方且不重叠")
        try expect(label.intrinsicContentSize.width <= label.bounds.width + 1, "最长提示文案必须完整显示")
    }
}
