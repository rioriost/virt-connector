import Foundation

enum PowerEventAction: String, Codable, CaseIterable, Identifiable {
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

struct ManagedMatterDevice: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var nodeID: String
    var endpointID: String
    var isEnabled: Bool
    var wakeAction: PowerEventAction
    var sleepAction: PowerEventAction
    var powerOffAction: PowerEventAction

    init(
        id: UUID = UUID(),
        displayName: String,
        nodeID: String = "",
        endpointID: String = "1",
        isEnabled: Bool = true,
        wakeAction: PowerEventAction = .turnOn,
        sleepAction: PowerEventAction = .turnOff,
        powerOffAction: PowerEventAction = .turnOff
    ) {
        self.id = id
        self.displayName = displayName
        self.nodeID = nodeID
        self.endpointID = endpointID
        self.isEnabled = isEnabled
        self.wakeAction = wakeAction
        self.sleepAction = sleepAction
        self.powerOffAction = powerOffAction
    }

    var matterConfiguration: MatterDeviceConfiguration {
        MatterDeviceConfiguration(
            id: id,
            displayName: displayName,
            nodeID: nodeID,
            endpointID: endpointID
        )
    }

    func action(for event: PowerEvent) -> PowerEventAction {
        switch event {
        case .wake:
            wakeAction
        case .sleep:
            sleepAction
        case .powerOff:
            powerOffAction
        }
    }
}
