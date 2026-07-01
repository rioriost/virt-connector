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
            await send(state, to: settings.enabledConfiguredDevices, reason: .manual)
        }
    }

    private func handle(_ event: PowerEvent) async {
        guard shouldAccept(event) else { return }
        lastEvent = event
        lastEventDate = Date()
        await send(event, reason: event.reason)
    }

    private func send(_ event: PowerEvent, reason: PowerTriggerReason) async {
        let requests = settings.enabledConfiguredDevices.compactMap { device -> (ManagedMatterDevice, DevicePowerState)? in
            guard let state = device.action(for: event).requestedState else { return nil }
            return (device, state)
        }

        guard !requests.isEmpty else {
            settings.lastErrorMessage = "-"
            settings.lastTriggerReason = reason.rawValue
            settings.lastRequestDate = Date()
            return
        }

        for (device, state) in requests {
            await send(state, to: [device], reason: reason)
        }
    }

    private func send(_ state: DevicePowerState, to devices: [ManagedMatterDevice], reason: PowerTriggerReason) async {
        guard !devices.isEmpty else {
            settings.lastErrorMessage = DevicePowerError.noEnabledDevices.localizedDescription
            return
        }

        var errors: [String] = []
        for device in devices {
            do {
                try await controller.setPower(state, for: device.matterConfiguration, reason: reason)
            } catch {
                errors.append("\(device.displayName): \(error.localizedDescription)")
                logger.error("Device power request failed for \(device.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        if errors.isEmpty {
            settings.lastErrorMessage = "-"
        } else {
            settings.lastErrorMessage = errors.joined(separator: " / ")
        }
    }

    private func shouldAccept(_ event: PowerEvent) -> Bool {
        guard lastEvent == event, let lastEventDate else { return true }
        return Date().timeIntervalSince(lastEventDate) > 2
    }
}
