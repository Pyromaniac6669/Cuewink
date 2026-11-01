import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let toast = ToastPanel()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private lazy var monitor = StateMonitor { [weak self] feedback in
        self?.toast.show(feedback)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let menuImage = Bundle.main.image(forResource: "MenuBarTemplate") else {
            NSApp.presentError(NSError(domain: "local.cuewink.prototype", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Cuewink 菜单栏图标资源缺失，请重新构建应用。"
            ]))
            NSApp.terminate(nil)
            return
        }
        menuImage.size = NSSize(width: 18, height: 18)
        menuImage.isTemplate = true
        menuImage.accessibilityDescription = "Cuewink"
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = menuImage
        item.button?.toolTip = "Cuewink · 剪贴板与大写锁定提示"
        let menu = NSMenu()
        let title = NSMenuItem(title: "Cuewink · 运行中", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Cuewink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.monitor.stop()
                self?.toast.hide()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.monitor.start()
            })
        }
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.toast.hide()
        })
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.toast.hide()
        }
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        toast.hide()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
