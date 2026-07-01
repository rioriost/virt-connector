import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let nodeID = "matter.nodeID"
        static let endpointID = "matter.endpointID"
        static let devices = "matter.devices"
        static let selectedDeviceID = "matter.selectedDeviceID"
        static let enableWake = "events.enableWake"
        static let enableSleep = "events.enableSleep"
        static let enablePowerOff = "events.enablePowerOff"
        static let lastRequestedPowerState = "state.lastRequestedPowerState"
        static let lastTriggerReason = "state.lastTriggerReason"
        static let lastRequestDate = "state.lastRequestDate"
        static let lastErrorMessage = "state.lastErrorMessage"
    }

    private let defaults: UserDefaults

    @Published var devices: [ManagedMatterDevice] {
        didSet {
            saveDevices()
            if let selectedDeviceID, !devices.contains(where: { $0.id == selectedDeviceID }) {
                self.selectedDeviceID = devices.first?.id
            }
        }
    }

    @Published var selectedDeviceID: UUID? {
        didSet {
            defaults.set(selectedDeviceID?.uuidString, forKey: Key.selectedDeviceID)
        }
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

    @Published var lastErrorMessage: String {
        didSet { defaults.set(lastErrorMessage, forKey: Key.lastErrorMessage) }
    }

    var selectedDevice: ManagedMatterDevice? {
        guard let selectedDeviceID else { return devices.first }
        return devices.first { $0.id == selectedDeviceID } ?? devices.first
    }

    var enabledConfiguredDevices: [ManagedMatterDevice] {
        devices.filter { $0.isEnabled && $0.matterConfiguration.isConfigured }
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

        let loadedDevices = Self.loadDevices(from: defaults) ?? Self.migratedDevices(from: defaults)
        devices = loadedDevices
        if
            let selectedDeviceIDString = defaults.string(forKey: Key.selectedDeviceID),
            let id = UUID(uuidString: selectedDeviceIDString),
            loadedDevices.contains(where: { $0.id == id })
        {
            selectedDeviceID = id
        } else {
            selectedDeviceID = loadedDevices.first?.id
        }
        enableWake = defaults.bool(forKey: Key.enableWake)
        enableSleep = defaults.bool(forKey: Key.enableSleep)
        enablePowerOff = defaults.bool(forKey: Key.enablePowerOff)
        lastRequestedPowerState = defaults.string(forKey: Key.lastRequestedPowerState) ?? "-"
        lastTriggerReason = defaults.string(forKey: Key.lastTriggerReason) ?? "-"
        lastRequestDate = defaults.object(forKey: Key.lastRequestDate) as? Date
        lastErrorMessage = defaults.string(forKey: Key.lastErrorMessage) ?? "-"
    }

    func addDevice() {
        var device = ManagedMatterDevice(displayName: String(localized: "settings.device.defaultName"))
        if devices.contains(where: { $0.displayName == device.displayName }) {
            device.displayName = String(format: String(localized: "settings.device.defaultNameWithNumber"), devices.count + 1)
        }
        devices.append(device)
        selectedDeviceID = device.id
    }

    func removeSelectedDevice() {
        guard let selectedDeviceID else { return }
        devices.removeAll { $0.id == selectedDeviceID }
        self.selectedDeviceID = devices.first?.id
    }

    func binding(for deviceID: UUID) -> Binding<ManagedMatterDevice>? {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return nil }
        return Binding(
            get: { self.devices[index] },
            set: { self.devices[index] = $0 }
        )
    }

    private func saveDevices() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: Key.devices)
    }

    private static func loadDevices(from defaults: UserDefaults) -> [ManagedMatterDevice]? {
        guard let data = defaults.data(forKey: Key.devices) else { return nil }
        return try? JSONDecoder().decode([ManagedMatterDevice].self, from: data)
    }

    private static func migratedDevices(from defaults: UserDefaults) -> [ManagedMatterDevice] {
        let nodeID = defaults.string(forKey: Key.nodeID) ?? ""
        let endpointID = defaults.string(forKey: Key.endpointID) ?? "1"
        return [
            ManagedMatterDevice(
                displayName: String(localized: "settings.device.ledStrip"),
                nodeID: nodeID,
                endpointID: endpointID
            )
        ]
    }
}
