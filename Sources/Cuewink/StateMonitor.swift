import AppKit
import CoreGraphics

enum Feedback: Equatable {
    case clipboardUpdated
    case capsLock(Bool)

    func message(in language: InterfaceLanguage) -> String {
        let text: LocalizedText
        switch self {
        case .clipboardUpdated: text = .clipboardUpdated
        case .capsLock(true): text = .capsLockOn
        case .capsLock(false): text = .capsLockOff
        }
        return text.string(in: language)
    }
}

struct ChangeTracker {
    private var lastCount: Int?
    private var lastCapsLock: Bool?
    private var pendingSince: TimeInterval?
    private let settlingInterval: TimeInterval

    init(settlingInterval: TimeInterval = 0.1) {
        self.settlingInterval = settlingInterval
    }

    mutating func reset() {
        lastCount = nil
        lastCapsLock = nil
        pendingSince = nil
    }

    mutating func sample(
        count: Int, capsLock: Bool, now: TimeInterval,
        hasTypes: () -> Bool
    ) -> [Feedback] {
        guard let previousCount = lastCount, let previousCapsLock = lastCapsLock else {
            lastCount = count
            lastCapsLock = capsLock
            return []
        }

        var feedback: [Feedback] = []
        if count != previousCount {
            lastCount = count
            pendingSince = now
        }
        // 清空后可能由同一所有者延迟声明类型，保留候选更新直到有类型可用。
        if let since = pendingSince, now - since >= settlingInterval, hasTypes() {
            pendingSince = nil
            feedback.append(.clipboardUpdated)
        }
        if capsLock != previousCapsLock {
            lastCapsLock = capsLock
            feedback.append(.capsLock(capsLock))
        }
        return feedback
    }
}

final class StateMonitor {
    private let pasteboard: NSPasteboard
    private let readCapsLock: () -> Bool
    private let clock: () -> TimeInterval
    private let onFeedback: (Feedback) -> Void
    private var tracker = ChangeTracker()
    private var timer: Timer?

    init(
        pasteboard: NSPasteboard = .general,
        readCapsLock: @escaping () -> Bool = {
            CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        },
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        onFeedback: @escaping (Feedback) -> Void
    ) {
        self.pasteboard = pasteboard
        self.readCapsLock = readCapsLock
        self.clock = clock
        self.onFeedback = onFeedback
    }

    func start() {
        stop()
        poll()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = 0.02
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        tracker.reset()
    }

    func poll() {
        let count = pasteboard.changeCount
        let feedback = tracker.sample(count: count, capsLock: readCapsLock(), now: clock()) {
            // 只检查类型和版本，不读取正文；读取期间改写的版本留到下次处理。
            let hasTypes = !(pasteboard.types ?? []).isEmpty
            return hasTypes && pasteboard.changeCount == count
        }
        feedback.forEach(onFeedback)
    }

    deinit {
        timer?.invalidate()
    }
}
