import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let nodeID = "matter.nodeID"
        static let endpointID = "matter.endpointID"
        static let enableWake = "events.enableWake"
        static let enableSleep = "events.enableSleep"
        static let enablePowerOff = "events.enablePowerOff"
        static let lastRequestedPowerState = "state.lastRequestedPowerState"
        static let lastTriggerReason = "state.lastTriggerReason"
        static let lastRequestDate = "state.lastRequestDate"
    }

    private let defaults: UserDefaults

    @Published var nodeID: String {
        didSet { defaults.set(nodeID, forKey: Key.nodeID) }
    }

    @Published var endpointID: String {
        didSet { defaults.set(endpointID, forKey: Key.endpointID) }
    }

    @Published var enableWake: Bool {
        didSet { defaults.set(enableWake, forKey: Key.enableWake) }
    }

    @Published var enableSleep: Bool {
        didSet { defaults.set(enableSleep, forKey: Key.enableSleep) }
    }

    @Published var enablePowerOff: Bool {
        didSet { defaults.set(enablePowerOff, forKey: Key.enablePowerOff) }
    }

    @Published var lastRequestedPowerState: String {
        didSet { defaults.set(lastRequestedPowerState, forKey: Key.lastRequestedPowerState) }
    }

    @Published var lastTriggerReason: String {
        didSet { defaults.set(lastTriggerReason, forKey: Key.lastTriggerReason) }
    }

    @Published var lastRequestDate: Date? {
        didSet { defaults.set(lastRequestDate, forKey: Key.lastRequestDate) }
    }

    var matterDeviceConfiguration: MatterDeviceConfiguration {
        MatterDeviceConfiguration(nodeID: nodeID, endpointID: endpointID)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Key.enableWake) == nil {
            defaults.set(true, forKey: Key.enableWake)
        }
        if defaults.object(forKey: Key.enableSleep) == nil {
            defaults.set(true, forKey: Key.enableSleep)
        }
        if defaults.object(forKey: Key.enablePowerOff) == nil {
            defaults.set(true, forKey: Key.enablePowerOff)
        }

        nodeID = defaults.string(forKey: Key.nodeID) ?? ""
        endpointID = defaults.string(forKey: Key.endpointID) ?? "1"
        enableWake = defaults.bool(forKey: Key.enableWake)
        enableSleep = defaults.bool(forKey: Key.enableSleep)
        enablePowerOff = defaults.bool(forKey: Key.enablePowerOff)
        lastRequestedPowerState = defaults.string(forKey: Key.lastRequestedPowerState) ?? "-"
        lastTriggerReason = defaults.string(forKey: Key.lastTriggerReason) ?? "-"
        lastRequestDate = defaults.object(forKey: Key.lastRequestDate) as? Date
    }
}
