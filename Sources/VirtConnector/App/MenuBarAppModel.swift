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
        coordinator.setMonitoringEnabled(true)
    }

    func turnOff() {
        coordinator.setMonitoringEnabled(false)
    }

    func openSettings() {
        settingsWindowController.show()
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
