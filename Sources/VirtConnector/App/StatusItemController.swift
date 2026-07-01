import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let coordinator: PowerCoordinator
    private let settingsWindowController: SettingsWindowController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(coordinator: PowerCoordinator) {
        self.coordinator = coordinator
        settingsWindowController = SettingsWindowController(coordinator: coordinator)
        super.init()
        configure()
    }

    private func configure() {
        statusItem.button?.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: "VirtConnector")
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(menuItem("menu.turnOn", action: #selector(turnOn)))
        menu.addItem(menuItem("menu.turnOff", action: #selector(turnOff)))
        menu.addItem(.separator())
        menu.addItem(menuItem("menu.settings", action: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem("menu.quit", action: #selector(quit)))
        statusItem.menu = menu
    }

    private func menuItem(_ titleKey: String.LocalizationValue, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: titleKey), action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func turnOn() {
        coordinator.requestPower(.on)
    }

    @objc private func turnOff() {
        coordinator.requestPower(.off)
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
