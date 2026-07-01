import Foundation
import OSLog

@MainActor
final class PowerCoordinator {
    let settings: AppSettings
    let loginItemManager: LoginItemManager

    private let controller: DevicePowerControlling
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "PowerCoordinator")
    private var monitor: PowerEventMonitor?
    private var lastEventDate: Date?
    private var lastEvent: PowerEvent?

    init(settings: AppSettings = AppSettings(), loginItemManager: LoginItemManager = LoginItemManager()) {
        self.settings = settings
        self.loginItemManager = loginItemManager
        controller = MatterDevicePowerController(settings: settings)
    }

    func start() {
        let monitor = PowerEventMonitor(settings: settings) { [weak self] event in
            await self?.handle(event)
        }
        self.monitor = monitor
        monitor.start()
    }

    func requestPower(_ state: DevicePowerState) {
        Task { @MainActor in
            await send(state, reason: .manual)
        }
    }

    private func handle(_ event: PowerEvent) async {
        guard shouldAccept(event) else { return }
        lastEvent = event
        lastEventDate = Date()
        await send(event.requestedState, reason: event.reason)
    }

    private func send(_ state: DevicePowerState, reason: PowerTriggerReason) async {
        do {
            try await controller.setPower(state, reason: reason)
        } catch {
            logger.error("Device power request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func shouldAccept(_ event: PowerEvent) -> Bool {
        guard lastEvent == event, let lastEventDate else { return true }
        return Date().timeIntervalSince(lastEventDate) > 2
    }
}
