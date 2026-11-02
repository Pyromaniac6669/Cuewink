import AppKit

private final class SettingsDocument: NSView {
    override var isFlipped: Bool { true }
}

private final class SettingsGroup: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        NSColor.controlBackgroundColor.setFill()
        shape.fill()
        NSColor.separatorColor.setStroke()
        shape.stroke()
    }
}

private final class PositionButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on
        let size = NSSize(width: selected ? 31 : 12, height: selected ? 24 : 12)
        let rect = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        let shape = NSBezierPath(roundedRect: rect, xRadius: selected ? 5 : 3, yRadius: selected ? 5 : 3)
        if selected {
            NSColor.systemBlue.setFill()
            shape.fill()
            NSColor.white.setStroke()
            let check = NSBezierPath()
            check.lineWidth = 2
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            let direction: CGFloat = isFlipped ? -1 : 1
            check.move(to: NSPoint(x: rect.midX - 6, y: rect.midY))
            check.line(to: NSPoint(x: rect.midX - 2, y: rect.midY - 4 * direction))
            check.line(to: NSPoint(x: rect.midX + 6, y: rect.midY + 4 * direction))
            check.stroke()
        } else {
            NSColor(srgbRed: 0.93, green: 0.96, blue: 0.99, alpha: 0.55).setFill()
            shape.fill()
            NSColor(srgbRed: 0.60, green: 0.66, blue: 0.72, alpha: 1).setStroke()
            shape.stroke()
        }
    }

    override var focusRingMaskBounds: NSRect { bounds.insetBy(dx: 6, dy: 3) }
    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: focusRingMaskBounds, xRadius: 5, yRadius: 5).fill()
    }
}

final class ScreenPositionPicker: NSView {
    var onChange: ((ToastPosition) -> Void)?
    var position: ToastPosition = .bottomCenter {
        didSet {
            for button in buttons {
                button.state = button.tag == position.rawValue ? .on : .off
                button.needsDisplay = true
            }
        }
    }
    private var buttons: [NSButton] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for position in ToastPosition.allCases {
            let button = PositionButton(title: "", target: self, action: #selector(selectPosition(_:)))
            button.tag = position.rawValue
            button.setButtonType(.toggle)
            button.isBordered = false
            button.setAccessibilityLabel(position.title)
            button.toolTip = position.title
            button.state = position == self.position ? .on : .off
            buttons.append(button)
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("不支持从归档初始化") }

    override func layout() {
        super.layout()
        let area = bounds.insetBy(dx: 22, dy: 24)
        for button in buttons {
            button.frame = NSRect(
                x: area.minX + CGFloat(button.tag % 3) * area.width / 3,
                y: area.minY + CGFloat(2 - button.tag / 3) * area.height / 3,
                width: area.width / 3, height: area.height / 3
            )
        }
    }

    @objc private func selectPosition(_ sender: NSButton) {
        guard let selected = ToastPosition(rawValue: sender.tag) else { return }
        position = selected
        onChange?(selected)
    }

    override func draw(_ dirtyRect: NSRect) {
        let outer = NSBezierPath(roundedRect: bounds, xRadius: 11, yRadius: 11)
        NSColor(srgbRed: 0.27, green: 0.28, blue: 0.30, alpha: 1).setFill()
        outer.fill()
        NSGraphicsContext.saveGraphicsState()
        let interior = bounds.insetBy(dx: 6, dy: 6)
        NSBezierPath(roundedRect: interior, xRadius: 5, yRadius: 5).addClip()
        NSGradient(starting: NSColor(srgbRed: 0.86, green: 0.91, blue: 0.92, alpha: 1), ending: NSColor(srgbRed: 0.78, green: 0.82, blue: 0.89, alpha: 1))?.draw(in: interior, angle: -30)
        NSColor(white: 1, alpha: 0.4).setFill()
        NSRect(x: interior.minX, y: interior.maxY - 11, width: interior.width, height: 11).fill()
        NSColor(srgbRed: 0.26, green: 0.30, blue: 0.35, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 12, y: interior.maxY - 8, width: 5, height: 5)).fill()
        NSColor(srgbRed: 0.68, green: 0.72, blue: 0.76, alpha: 1).setFill()
        NSRect(x: 22, y: interior.maxY - 6, width: 16, height: 2).fill()
        NSRect(x: 43, y: interior.maxY - 6, width: 11, height: 2).fill()
        NSColor(white: 1, alpha: 0.25).setFill()
        NSBezierPath(roundedRect: NSRect(x: bounds.width * 0.25, y: -8, width: bounds.width * 0.5, height: 38), xRadius: 28, yRadius: 28).fill()
        NSColor(white: 1, alpha: 0.35).setFill()
        NSBezierPath(roundedRect: NSRect(x: bounds.width * 0.34, y: 12, width: bounds.width * 0.32, height: 8), xRadius: 4, yRadius: 4).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let store: PreferencesStore
    private let loginItem: LoginItemManaging
    private let playSound: () -> Void
    private let loginSwitch = NSSwitch()
    private let clipboardSwitch = NSSwitch()
    private let capsLockSwitch = NSSwitch()
    private let soundSwitch = NSSwitch()
    private let picker = ScreenPositionPicker(frame: .zero)
    private let positionLabel = NSTextField(labelWithString: "")
    private let durationLabel = NSTextField(labelWithString: "")
    private let opacityLabel = NSTextField(labelWithString: "")
    private let loginNotice = NSTextField(wrappingLabelWithString: "")
    private let loginHelp = NSButton(title: "前往系统设置", target: nil, action: nil)
    private let loginDetails = NSView()
    private var loginFailure: (enabled: Bool, detail: String)?
    private let durationControl = NSSegmentedControl(labels: ["短", "中", "长"], trackingMode: .selectOne, target: nil, action: nil)
    private let sizeControl = NSSegmentedControl(labels: ["小", "中", "大"], trackingMode: .selectOne, target: nil, action: nil)
    private let opacitySlider = NSSlider(value: 85, minValue: 40, maxValue: 100, target: nil, action: nil)

    init(store: PreferencesStore, loginItem: LoginItemManaging = SystemLoginItem(), playSound: @escaping () -> Void) {
        self.store = store
        self.loginItem = loginItem
        self.playSound = playSound
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 820
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: min(736, availableHeight - 70)), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Cuewink 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        refresh()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("不支持从归档初始化") }

    func present() {
        loginFailure = nil
        refresh()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) { refreshLoginStatus() }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor), scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        let document = SettingsDocument()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true

        let positionHeading = NSView()
        let heading = label("屏幕显示位置", size: 12, weight: .semibold)
        positionLabel.font = .systemFont(ofSize: 12)
        positionLabel.textColor = .secondaryLabelColor
        positionHeading.addSubview(heading)
        positionHeading.addSubview(positionLabel)
        for view in [heading, positionLabel] { view.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            positionHeading.heightAnchor.constraint(equalToConstant: 18),
            heading.leadingAnchor.constraint(equalTo: positionHeading.leadingAnchor), heading.centerYAnchor.constraint(equalTo: positionHeading.centerYAnchor),
            positionLabel.trailingAnchor.constraint(equalTo: positionHeading.trailingAnchor), positionLabel.centerYAnchor.constraint(equalTo: positionHeading.centerYAnchor)
        ])
        picker.heightAnchor.constraint(equalTo: picker.widthAnchor, multiplier: 1 / 1.88).isActive = true
        picker.onChange = { [weak self] position in self?.update { $0.position = position } }
        let positionSection = column([positionHeading, picker], spacing: 9)

        for (control, title) in [(loginSwitch, "登录时启动"), (clipboardSwitch, "剪贴板更新提示"), (capsLockSwitch, "大写锁定提示"), (soundSwitch, "提示音")] {
            control.target = self
            control.action = #selector(toggle(_:))
            control.setAccessibilityLabel(title)
        }
        let audition = NSButton(title: "试听", target: self, action: #selector(audition(_:)))
        audition.bezelStyle = .rounded
        audition.controlSize = .small
        let soundControls = NSStackView(views: [audition, soundSwitch])
        soundControls.spacing = 8
        soundControls.alignment = .centerY
        loginNotice.font = .systemFont(ofSize: 11)
        loginNotice.textColor = .secondaryLabelColor
        loginNotice.identifier = NSUserInterfaceItemIdentifier("loginNotice")
        loginHelp.bezelStyle = .rounded
        loginHelp.controlSize = .small
        loginHelp.target = self
        loginHelp.action = #selector(openLoginSettings(_:))
        let details = NSStackView(views: [loginNotice, loginHelp])
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 5
        details.translatesAutoresizingMaskIntoConstraints = false
        loginNotice.translatesAutoresizingMaskIntoConstraints = false
        loginDetails.addSubview(details)
        NSLayoutConstraint.activate([
            details.leadingAnchor.constraint(equalTo: loginDetails.leadingAnchor, constant: 12),
            details.trailingAnchor.constraint(equalTo: loginDetails.trailingAnchor, constant: -12),
            details.topAnchor.constraint(equalTo: loginDetails.topAnchor),
            details.bottomAnchor.constraint(equalTo: loginDetails.bottomAnchor, constant: -10),
            loginNotice.widthAnchor.constraint(equalTo: details.widthAnchor)
        ])
        loginDetails.identifier = NSUserInterfaceItemIdentifier("loginDetails")
        let loginRow = column([row("登录时启动", control: loginSwitch), loginDetails], spacing: 0)
        loginRow.identifier = NSUserInterfaceItemIdentifier("loginSettingRow")
        let general = section("通用", rows: [
            loginRow,
            row("剪贴板更新提示", control: clipboardSwitch),
            row("大写锁定提示", control: capsLockSwitch),
            row("提示音", control: soundControls)
        ])

        durationLabel.font = .systemFont(ofSize: 11)
        durationLabel.textColor = .secondaryLabelColor
        for control in [durationControl, sizeControl] {
            control.segmentStyle = .rounded
            control.target = self
            control.action = #selector(selectSegment(_:))
            control.widthAnchor.constraint(equalToConstant: 184).isActive = true
        }
        durationControl.setAccessibilityLabel("显示时长")
        sizeControl.setAccessibilityLabel("浮层尺寸")
        opacitySlider.target = self
        opacitySlider.action = #selector(changeOpacity(_:))
        opacitySlider.isContinuous = true
        opacitySlider.setAccessibilityLabel("背景不透明度")
        opacityLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        opacityLabel.textColor = .secondaryLabelColor
        opacityLabel.alignment = .right
        opacityLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true
        let opacityControl = NSStackView(views: [opacitySlider, opacityLabel])
        opacityControl.alignment = .centerY
        opacityControl.spacing = 9
        opacityControl.widthAnchor.constraint(equalToConstant: 184).isActive = true
        let display = section("显示", rows: [
            row("显示时长", control: durationControl, detail: durationLabel),
            row("浮层尺寸", control: sizeControl), row("背景不透明度", control: opacityControl)
        ])
        let footer = label("设置自动保存", size: 11)
        footer.textColor = .secondaryLabelColor
        footer.alignment = .center
        let stack = column([positionSection, general, display, footer], spacing: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -14)
        ])
    }

    private func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        return field
    }

    private func column(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func section(_ title: String, rows: [NSView]) -> NSView {
        var contents: [NSView] = []
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let line = NSBox()
                line.boxType = .separator
                line.heightAnchor.constraint(equalToConstant: 1).isActive = true
                contents.append(line)
            }
            contents.append(row)
        }
        let group = SettingsGroup()
        let rows = column(contents, spacing: 0)
        rows.translatesAutoresizingMaskIntoConstraints = false
        group.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: group.leadingAnchor), rows.trailingAnchor.constraint(equalTo: group.trailingAnchor),
            rows.topAnchor.constraint(equalTo: group.topAnchor), rows.bottomAnchor.constraint(equalTo: group.bottomAnchor)
        ])
        return column([label(title, size: 12, weight: .semibold), group], spacing: 6)
    }

    private func row(_ title: String, control: NSView, detail: NSView? = nil) -> NSView {
        let row = NSView()
        let text: NSView = detail.map { column([label(title), $0], spacing: 2) } ?? label(title)
        for view in [text, control] { view.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(view) }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: detail == nil ? 43 : 50),
            text.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12), text.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12), control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            text.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -12)
        ])
        return row
    }

    private func update(_ change: (inout Preferences) -> Void) {
        change(&store.value)
        refresh()
    }

    private func refresh() {
        let value = store.value
        clipboardSwitch.state = value.clipboardEnabled ? .on : .off
        capsLockSwitch.state = value.capsLockEnabled ? .on : .off
        soundSwitch.state = value.soundEnabled ? .on : .off
        picker.position = value.position
        positionLabel.stringValue = value.position.title
        durationControl.selectedSegment = value.duration.rawValue
        durationLabel.stringValue = "\(value.duration.seconds.formatted()) 秒"
        sizeControl.selectedSegment = value.size.rawValue
        opacitySlider.doubleValue = value.backgroundOpacity * 100
        opacityLabel.stringValue = "\(Int((value.backgroundOpacity * 100).rounded()))%"
        refreshLoginStatus()
    }

    private func refreshLoginStatus() {
        let status = loginItem.status
        loginSwitch.state = status == .enabled || status == .requiresApproval ? .on : .off
        if let failure = loginFailure,
           (failure.enabled && status == .enabled) || (!failure.enabled && status == .disabled) {
            loginFailure = nil
        }
        loginNotice.toolTip = loginFailure?.detail
        loginNotice.textColor = loginFailure == nil ? .secondaryLabelColor : .systemRed
        if let failure = loginFailure {
            loginNotice.stringValue = failure.enabled ? "未能开启登录时启动，请重试。" : "未能关闭登录时启动，请重试。"
        } else if status == .requiresApproval {
            loginNotice.stringValue = "需要在系统设置中允许 Cuewink 登录时启动。"
        } else if status == .unconfirmed {
            loginNotice.stringValue = "暂时无法获取登录启动状态。"
        } else {
            loginNotice.stringValue = ""
        }
        loginHelp.isHidden = status != .requiresApproval
        loginDetails.isHidden = loginNotice.stringValue.isEmpty
    }

    @objc private func toggle(_ sender: NSSwitch) {
        if sender === loginSwitch {
            let enabled = sender.state == .on
            loginFailure = nil
            do { try loginItem.setEnabled(enabled) }
            catch {
                loginFailure = (enabled: enabled, detail: error.localizedDescription)
            }
            refreshLoginStatus()
        } else {
            update {
                if sender === clipboardSwitch { $0.clipboardEnabled = sender.state == .on }
                else if sender === capsLockSwitch { $0.capsLockEnabled = sender.state == .on }
                else if sender === soundSwitch { $0.soundEnabled = sender.state == .on }
            }
        }
    }

    @objc private func selectSegment(_ sender: NSSegmentedControl) {
        update {
            if sender === durationControl, let value = ToastDuration(rawValue: sender.selectedSegment) { $0.duration = value }
            else if sender === sizeControl, let value = ToastSize(rawValue: sender.selectedSegment) { $0.size = value }
        }
    }

    @objc private func changeOpacity(_ sender: NSSlider) {
        update { $0.backgroundOpacity = sender.doubleValue.rounded() / 100 }
    }

    @objc private func audition(_ sender: NSButton) { playSound() }
    @objc private func openLoginSettings(_ sender: NSButton) { loginItem.openSystemSettings() }
}
