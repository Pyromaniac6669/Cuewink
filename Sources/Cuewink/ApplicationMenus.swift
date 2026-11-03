import AppKit

final class ApplicationMenus {
    let statusMenu = NSMenu()
    let mainMenu = NSMenu()
    private let statusTitle = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var translatedItems: [(NSMenuItem, LocalizedText)] = []

    init(settingsTarget: AnyObject, settingsAction: Selector) {
        statusTitle.isEnabled = false
        statusMenu.addItem(statusTitle)
        statusMenu.addItem(.separator())
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Cuewink")
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        for menu in [statusMenu, applicationMenu] {
            let settings = menu.addItem(withTitle: "", action: settingsAction, keyEquivalent: ",")
            settings.target = settingsTarget
            translatedItems.append((settings, .settings))
            if menu === applicationMenu {
                let close = menu.addItem(withTitle: "", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
                translatedItems.append((close, .closeWindow))
            }
            menu.addItem(.separator())
            let quit = menu.addItem(withTitle: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            translatedItems.append((quit, .quit))
        }
    }

    func update(_ preferences: Preferences) {
        let language = preferences.interfaceLanguage
        statusTitle.title = (preferences.clipboardEnabled || preferences.capsLockEnabled ? LocalizedText.running : .feedbackDisabled).string(in: language)
        for (item, text) in translatedItems { item.title = text.string(in: language) }
    }
}
