import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menuTitle: NSMenuItem?
    private let preferences = PreferencesStore()
    private lazy var toast = ToastPanel(preferences: preferences.value)
    private var settings: SettingsWindowController?
    private let sound = NSSound(named: NSSound.Name("Tink"))
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private lazy var monitor = StateMonitor { [weak self] feedback in
        guard let self, self.preferences.value.allows(feedback) else { return }
        self.toast.show(feedback)
        if self.preferences.value.soundEnabled { self.playSound() }
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
        menuTitle = title
        menu.addItem(.separator())
        let settingsItem = menu.addItem(withTitle: "设置…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Cuewink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Cuewink")
        let shortcut = applicationMenu.addItem(withTitle: "设置…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        shortcut.target = self
        applicationMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "退出 Cuewink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
        preferences.onChange = { [weak self] value in
            self?.toast.apply(value)
            self?.updateMenu(value)
        }
        updateMenu(preferences.value)

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

    private func updateMenu(_ value: Preferences) {
        menuTitle?.title = value.clipboardEnabled || value.capsLockEnabled ? "Cuewink · 运行中" : "Cuewink · 提示已关闭"
    }

    private func playSound() {
        sound?.stop()
        sound?.play()
    }

    @objc private func openSettings(_ sender: Any?) {
        if settings == nil {
            settings = SettingsWindowController(store: preferences) { [weak self] in self?.playSound() }
        }
        settings?.present()
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
