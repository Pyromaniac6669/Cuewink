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
    private let displayDuration: TimeInterval
    private var dismissTimer: Timer?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(displayDuration: TimeInterval = 1.0) {
        self.displayDuration = displayDuration
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

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 22.4
        background.layer?.masksToBounds = true
        contentView = background

        let tint = ToastTintView(frame: background.bounds)
        tint.autoresizingMask = [.width, .height]
        background.addSubview(tint)

        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(icon)

        label.font = .systemFont(ofSize: 17.6, weight: .semibold)
        label.textColor = NSColor(white: 0.96, alpha: 1)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            icon.topAnchor.constraint(equalTo: background.topAnchor, constant: 35.2),
            icon.widthAnchor.constraint(equalToConstant: 70.4),
            icon.heightAnchor.constraint(equalToConstant: 70.4),
            label.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 19.2),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: background.leadingAnchor, constant: 12.8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: background.trailingAnchor, constant: -12.8)
        ])
    }

    func show(_ feedback: Feedback, on screen: NSScreen? = NSScreen.main) {
        guard let screen else { return }
        dismissTimer?.invalidate()
        icon.image = Self.image(for: feedback)
        label.stringValue = feedback.message
        let area = screen.visibleFrame
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.minY + 32))
        orderFrontRegardless()

        let timer = Timer(timeInterval: displayDuration, repeats: false) { [weak self] _ in
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
        orderOut(nil)
    }

    deinit {
        dismissTimer?.invalidate()
    }
}
