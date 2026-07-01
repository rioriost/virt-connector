import Foundation

enum PowerEvent {
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
