import AppKit

final class ToastPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private let displayDuration: TimeInterval
    private var dismissTimer: Timer?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(displayDuration: TimeInterval = 1.0) {
        self.displayDuration = displayDuration
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 48),
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
        hasShadow = true
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        contentView = background

        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: background.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: background.trailingAnchor, constant: -16)
        ])
    }

    func show(_ feedback: Feedback, on screen: NSScreen? = NSScreen.main) {
        guard let screen else { return }
        dismissTimer?.invalidate()
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

    func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        orderOut(nil)
    }

    deinit {
        dismissTimer?.invalidate()
    }
}
