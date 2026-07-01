import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: PowerCoordinator?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let coordinator = PowerCoordinator()
        self.coordinator = coordinator
        statusItemController = StatusItemController(coordinator: coordinator)
        coordinator.start()
    }
}
