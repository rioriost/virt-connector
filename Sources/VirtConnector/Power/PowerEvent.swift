import Foundation

enum PowerEvent {
    case wake
    case sleep
    case powerOff

    var requestedState: DevicePowerState {
        switch self {
        case .wake:
            .on
        case .sleep, .powerOff:
            .off
        }
    }

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
