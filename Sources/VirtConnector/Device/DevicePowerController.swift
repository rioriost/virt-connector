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
    case unsupportedBackend

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            String(localized: "error.device.notConfigured")
        case .unsupportedBackend:
            String(localized: "error.device.unsupportedBackend")
        }
    }
}

@MainActor
protocol DevicePowerControlling {
    func setPower(_ state: DevicePowerState, reason: PowerTriggerReason) async throws
}
