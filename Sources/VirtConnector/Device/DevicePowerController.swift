import Foundation

enum DevicePowerState: String {
    case on
    case off
}

enum PowerTriggerReason: String {
    case wake
    case sleep
    case powerOff
    case manual
    case appStart
}

enum DevicePowerError: LocalizedError {
    case notConfigured
    case noEnabledDevices
    case invalidDeviceConfiguration(String)
    case unsupportedBackend

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            String(localized: "error.device.notConfigured")
        case .noEnabledDevices:
            String(localized: "error.device.noEnabledDevices")
        case let .invalidDeviceConfiguration(deviceName):
            String(format: String(localized: "error.device.invalidConfiguration"), deviceName)
        case .unsupportedBackend:
            String(localized: "error.device.unsupportedBackend")
        }
    }
}

@MainActor
protocol DevicePowerControlling {
    func setPower(_ state: DevicePowerState, for configuration: MatterDeviceConfiguration, reason: PowerTriggerReason) async throws
}
