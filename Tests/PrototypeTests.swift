import AppKit

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
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
        let tests: [(String, () throws -> Void)] = [
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
            ("浮层完整窗口没有额外亮边", toastWindowEdge)
        ]
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
        let panel = ToastPanel(displayDuration: 0.2)
        defer { panel.hide() }
        try expect(!panel.canBecomeKey && !panel.canBecomeMain && panel.ignoresMouseEvents, "浮层必须不接收焦点和点击")
        panel.show(.clipboardUpdated, on: screen)
        try expect(panel.isVisible, "浮层应可见")
        try expect(abs(panel.frame.midX - screen.visibleFrame.midX) < 1, "浮层应水平居中")
        try checkToastContent(panel, feedback: .clipboardUpdated)
        spin(0.12)
        panel.show(.capsLock(true), on: screen)
        try checkToastContent(panel, feedback: .capsLock(true))
        spin(0.12)
        try expect(panel.isVisible, "连续触发必须重置消失时间")
        try expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == activePID, "浮层不能激活自身或切走前台应用")
        spin(0.16)
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
        guard let edge = colors.firstIndex(where: { $0.alphaComponent > 0.99 }), edge + 10 <= colors.count else {
            throw TestFailure(description: "无法识别浮层的实色边缘")
        }
        func luminance(_ color: NSColor) -> CGFloat {
            0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
        }
        let rim = colors[edge..<edge + 2].map(luminance).max()!
        let interior = colors[edge + 4..<edge + 10].map(luminance).reduce(0, +) / 6
        try expect(rim - interior < 0.06, "完整窗口存在额外亮边，边缘亮度突增 \(rim - interior)")
    }

    static func checkToastContent(_ panel: ToastPanel, feedback: Feedback) throws {
        guard let content = panel.contentView,
              let icon = content.subviews.compactMap({ $0 as? NSImageView }).first,
              let label = content.subviews.compactMap({ $0 as? NSTextField }).first else {
            throw TestFailure(description: "浮层缺少图标或提示文字")
        }
        content.layoutSubtreeIfNeeded()
        try expect(abs(panel.frame.width - panel.frame.height) < 1, "浮层必须为正方形")
        try expect(icon.image != nil && !icon.isHidden, "每种状态必须显示图标")
        try expect(label.stringValue == feedback.message, "连续切换时必须更新文案")
        try expect(content.bounds.contains(icon.frame) && content.bounds.contains(label.frame), "图标和文字不能超出浮层")
        try expect(icon.frame.minY > label.frame.maxY, "图标应位于文字上方且不重叠")
        try expect(label.intrinsicContentSize.width <= label.bounds.width + 1, "最长提示文案必须完整显示")
    }
}
