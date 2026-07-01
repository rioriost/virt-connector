import AppKit
import Foundation

@MainActor
final class MenuBarAppModel: ObservableObject {
    let coordinator: PowerCoordinator
    private let settingsWindowController: SettingsWindowController

    init() {
        NSApp.setActivationPolicy(.accessory)

        coordinator = PowerCoordinator()
        settingsWindowController = SettingsWindowController(coordinator: coordinator)
        coordinator.start()
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
}
