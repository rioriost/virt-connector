import Foundation

enum DevicePowerState: String, Codable, Sendable {
    case on
    case off
}

enum PowerTriggerReason: String, Codable, Sendable {
    case wake
    case sleep
    case powerOff
    case manual
}

enum PowerEvent: Sendable {
    case wake
    case sleep
    case powerOff

    var reason: PowerTriggerReason {
        switch self {
        case .wake:
            .wake
        case .sleep:
            .sleep
        case .powerOff:
            .powerOff
        }
    }
}

enum PowerEventAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case noChange
    case turnOn
    case turnOff

    var id: String { rawValue }

    var requestedState: DevicePowerState? {
        switch self {
        case .noChange:
            nil
        case .turnOn:
            .on
        case .turnOff:
            .off
        }
    }

    var localizedTitle: String {
        switch self {
        case .noChange:
            String(localized: "settings.action.noChange")
        case .turnOn:
            String(localized: "settings.action.turnOn")
        case .turnOff:
            String(localized: "settings.action.turnOff")
        }
    }
}
