import AppKit
import Foundation

@MainActor
final class MenuBarAppModel: ObservableObject {
    let coordinator: PowerCoordinator
    private let settingsWindowController: SettingsWindowController
    private var statusItem: NSStatusItem?

    init() {
        NSApp.setActivationPolicy(.accessory)

        coordinator = PowerCoordinator()
        settingsWindowController = SettingsWindowController(coordinator: coordinator)
        coordinator.start()

        DispatchQueue.main.async { [weak self] in
            self?.configureStatusItemFallback()
        }
    }

    func turnOn() {
        coordinator.requestPower(.on)
    }

    func turnOff() {
        coordinator.requestPower(.off)
    }

    func openSettings() {
        settingsWindowController.show()
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItemFallback() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 140)
        self.statusItem = statusItem
        statusItem.isVisible = true
        statusItem.button?.title = "VirtConnector"
        statusItem.button?.toolTip = "VirtConnector"

        let menu = NSMenu()
        menu.addItem(menuItem("menu.turnOn", action: #selector(turnOnFromMenu)))
        menu.addItem(menuItem("menu.turnOff", action: #selector(turnOffFromMenu)))
        menu.addItem(.separator())
        menu.addItem(menuItem("menu.settings", action: #selector(openSettingsFromMenu)))
        menu.addItem(.separator())
        menu.addItem(menuItem("menu.quit", action: #selector(quitFromMenu)))
        statusItem.menu = menu
    }

    private func menuItem(_ titleKey: String.LocalizationValue, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: titleKey), action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func turnOnFromMenu() {
        turnOn()
    }

    @objc private func turnOffFromMenu() {
        turnOff()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    @objc private func quitFromMenu() {
        quit()
    }
}
