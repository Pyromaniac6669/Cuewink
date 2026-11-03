import AppKit

private final class ToastTintView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(
            starting: NSColor(srgbRed: 0.12, green: 0.18, blue: 0.26, alpha: 0.65),
            ending: NSColor(srgbRed: 0.05, green: 0.09, blue: 0.14, alpha: 0.75)
        )?.draw(in: bounds, angle: -90)
    }
}

final class ToastPanel: NSPanel {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let background = NSVisualEffectView()
    private var preferences: Preferences
    private var scaledConstraints: [NSLayoutConstraint] = []
    private var lastFeedback: Feedback?
    private var lastScreen: NSScreen?
    private var dismissTimer: Timer?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(preferences: Preferences = Preferences()) {
        self.preferences = preferences
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 192, height: 192),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        // macOS 13 的系统阴影会给此无边框窗口附加细亮边。
        hasShadow = false
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)

        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        content.layer?.masksToBounds = true
        contentView = content
        background.frame = content.bounds
        background.autoresizingMask = [.width, .height]
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.masksToBounds = true
        content.addSubview(background)

        let tint = ToastTintView(frame: background.bounds)
        tint.autoresizingMask = [.width, .height]
        background.addSubview(tint)

        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(icon)

        label.font = .systemFont(ofSize: 17.6, weight: .semibold)
        label.textColor = NSColor(white: 0.96, alpha: 1)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(label)
        scaledConstraints = [
            icon.topAnchor.constraint(equalTo: content.topAnchor, constant: 35.2),
            icon.widthAnchor.constraint(equalToConstant: 70.4),
            icon.heightAnchor.constraint(equalToConstant: 70.4),
            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 19.2),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 12.8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12.8)
        ]
        NSLayoutConstraint.activate(scaledConstraints + [
            icon.centerXAnchor.constraint(equalTo: content.centerXAnchor), label.centerXAnchor.constraint(equalTo: content.centerXAnchor)
        ])
        apply(preferences)
    }

    func show(_ feedback: Feedback, on screen: NSScreen? = NSScreen.main) {
        guard preferences.allows(feedback), let screen else { return }
        dismissTimer?.invalidate()
        lastFeedback = feedback
        lastScreen = screen
        icon.image = Self.image(for: feedback)
        label.stringValue = feedback.message(in: preferences.interfaceLanguage)
        setFrameOrigin(preferences.position.frame(size: preferences.size.points, in: screen.visibleFrame).origin)
        orderFrontRegardless()
        scheduleDismissal()
    }

    func apply(_ preferences: Preferences) {
        let durationChanged = self.preferences.duration != preferences.duration
        self.preferences = preferences
        let scale = preferences.size.points / 192
        contentView?.layer?.cornerRadius = 22.4 * scale
        background.layer?.cornerRadius = 22.4 * scale
        background.alphaValue = preferences.backgroundOpacity
        label.font = .systemFont(ofSize: 17.6 * scale, weight: .semibold)
        for (constraint, base) in zip(scaledConstraints, [35.2, 70.4, 70.4, 19.2, 12.8, -12.8]) {
            constraint.constant = base * scale
        }
        if let feedback = lastFeedback {
            label.stringValue = feedback.message(in: preferences.interfaceLanguage)
        }
        // 先更新文字和约束，避免旧字号的最小宽度把缩小后的窗口撑宽。
        contentView?.layoutSubtreeIfNeeded()
        setContentSize(NSSize(width: preferences.size.points, height: preferences.size.points))
        if isVisible, let feedback = lastFeedback, let screen = lastScreen {
            if !preferences.allows(feedback) { hide(); return }
            setFrameOrigin(preferences.position.frame(size: preferences.size.points, in: screen.visibleFrame).origin)
            if durationChanged { scheduleDismissal() }
        }
    }

    private func scheduleDismissal() {
        dismissTimer?.invalidate()
        let timer = Timer(timeInterval: preferences.duration.seconds, repeats: false) { [weak self] _ in
            self?.hide()
        }
        dismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func image(for feedback: Feedback) -> NSImage {
        NSImage(size: NSSize(width: 88, height: 88), flipped: false) { _ in
            let color: NSColor
            if feedback == .capsLock(false) {
                color = NSColor(srgbRed: 0.72, green: 0.76, blue: 0.80, alpha: 1)
            } else {
                color = NSColor(srgbRed: 0.59, green: 0.91, blue: 0.76, alpha: 1)
            }
            color.setStroke()
            color.setFill()
            let path = NSBezierPath()
            path.lineWidth = 7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            switch feedback {
            case .clipboardUpdated:
                path.move(to: NSPoint(x: 26, y: 69))
                path.line(to: NSPoint(x: 23, y: 69))
                path.curve(to: NSPoint(x: 17, y: 63), controlPoint1: NSPoint(x: 19, y: 69), controlPoint2: NSPoint(x: 17, y: 67))
                path.line(to: NSPoint(x: 17, y: 16))
                path.curve(to: NSPoint(x: 23, y: 10), controlPoint1: NSPoint(x: 17, y: 12), controlPoint2: NSPoint(x: 19, y: 10))
                path.line(to: NSPoint(x: 65, y: 10))
                path.curve(to: NSPoint(x: 71, y: 16), controlPoint1: NSPoint(x: 69, y: 10), controlPoint2: NSPoint(x: 71, y: 12))
                path.line(to: NSPoint(x: 71, y: 63))
                path.curve(to: NSPoint(x: 65, y: 69), controlPoint1: NSPoint(x: 71, y: 67), controlPoint2: NSPoint(x: 69, y: 69))
                path.line(to: NSPoint(x: 62, y: 69))
                path.move(to: NSPoint(x: 31, y: 40))
                path.line(to: NSPoint(x: 41, y: 30))
                path.line(to: NSPoint(x: 58, y: 50))
                path.stroke()

                let clip = NSBezierPath(roundedRect: NSRect(x: 30, y: 63, width: 28, height: 18), xRadius: 5, yRadius: 5)
                clip.appendOval(in: NSRect(x: 40, y: 71, width: 8, height: 8))
                clip.windingRule = .evenOdd
                clip.fill()
            case .capsLock:
                path.lineWidth = 9
                path.move(to: NSPoint(x: 17, y: 50))
                path.line(to: NSPoint(x: 44, y: 77))
                path.line(to: NSPoint(x: 71, y: 50))
                path.move(to: NSPoint(x: 44, y: 77))
                path.line(to: NSPoint(x: 44, y: 28))
                path.move(to: NSPoint(x: 22, y: 11))
                path.line(to: NSPoint(x: 66, y: 11))
                path.stroke()
            }
            return true
        }
    }

    func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        lastFeedback = nil
        lastScreen = nil
        orderOut(nil)
    }

    deinit {
        dismissTimer?.invalidate()
    }
}
