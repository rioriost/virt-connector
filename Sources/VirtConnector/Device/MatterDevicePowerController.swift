import Foundation
import OSLog

@MainActor
final class MatterDevicePowerController: DevicePowerControlling {
    private let settings: AppSettings
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "MatterDevicePowerController")

    init(settings: AppSettings) {
        self.settings = settings
    }

    func setPower(_ state: DevicePowerState, reason: PowerTriggerReason) async throws {
        let configuration = settings.matterDeviceConfiguration
        guard configuration.isConfigured else {
            throw DevicePowerError.notConfigured
        }

        settings.lastRequestedPowerState = state.rawValue
        settings.lastTriggerReason = reason.rawValue
        settings.lastRequestDate = Date()
        settings.lastErrorMessage = "-"

        logger.info(
            "Requested \(state.rawValue, privacy: .public) from \(reason.rawValue, privacy: .public) for node \(configuration.nodeID, privacy: .private), endpoint \(configuration.endpointID, privacy: .private)"
        )

        throw DevicePowerError.unsupportedBackend
    }
}
