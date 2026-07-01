import Foundation
import OSLog

@MainActor
final class MatterDevicePowerController: DevicePowerControlling {
    private let settings: AppSettings
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "MatterDevicePowerController")

    init(settings: AppSettings) {
        self.settings = settings
    }

    func setPower(_ state: DevicePowerState, for configuration: MatterDeviceConfiguration, reason: PowerTriggerReason) async throws {
        guard configuration.isConfigured else {
            throw DevicePowerError.invalidDeviceConfiguration(configuration.displayName)
        }

        let deviceName = configuration.displayName.isEmpty ? String(localized: "settings.device.untitled") : configuration.displayName
        settings.lastRequestedPowerState = "\(deviceName): \(state.rawValue)"
        settings.lastTriggerReason = reason.rawValue
        settings.lastRequestDate = Date()
        settings.lastErrorMessage = "-"

        logger.info(
            "Requested \(state.rawValue, privacy: .public) from \(reason.rawValue, privacy: .public) for \(deviceName, privacy: .public), node \(configuration.nodeID, privacy: .private), endpoint \(configuration.endpointID, privacy: .private)"
        )

        throw DevicePowerError.unsupportedBackend
    }
}
