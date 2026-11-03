import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menus: ApplicationMenus?
    private let preferences = PreferencesStore()
    private lazy var toast = ToastPanel(preferences: preferences.value)
    private var settings: SettingsWindowController?
    private let sound = NSSound(named: NSSound.Name("Tink"))
    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private var localeObserver: NSObjectProtocol?
    private lazy var monitor = StateMonitor { [weak self] feedback in
        guard let self, self.preferences.value.allows(feedback) else { return }
        self.toast.show(feedback)
        if self.preferences.value.soundEnabled { self.playSound() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let menuImage = Bundle.main.image(forResource: "MenuBarTemplate") else {
            NSApp.presentError(NSError(domain: "local.cuewink.prototype", code: 1, userInfo: [
                NSLocalizedDescriptionKey: LocalizedText.missingMenuIcon.string(in: preferences.value.interfaceLanguage)
            ]))
            NSApp.terminate(nil)
            return
        }
        menuImage.size = NSSize(width: 18, height: 18)
        menuImage.isTemplate = true
        menuImage.accessibilityDescription = "Cuewink"
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = menuImage
        let menus = ApplicationMenus(settingsTarget: self, settingsAction: #selector(openSettings(_:)))
        self.menus = menus
        item.menu = menus.statusMenu
        statusItem = item
        NSApp.mainMenu = menus.mainMenu
        preferences.onChange = { [weak self] value in
            self?.applyPreferences(value)
        }
        applyPreferences(preferences.value)
        localeObserver = NotificationCenter.default.addObserver(forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.applyPreferences(self.preferences.value)
        }

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

    private func applyPreferences(_ value: Preferences) {
        toast.apply(value)
        menus?.update(value)
        statusItem?.button?.toolTip = LocalizedText.statusTooltip.string(in: value.interfaceLanguage)
        settings?.refresh()
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
        if let localeObserver {
            NotificationCenter.default.removeObserver(localeObserver)
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
