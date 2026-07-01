import Foundation
import HomeKit
import OSLog
import SwiftUI

struct HomeKitDeviceActionConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var wakeAction: PowerEventAction
    var sleepAction: PowerEventAction
    var powerOffAction: PowerEventAction

    static let defaultValue = HomeKitDeviceActionConfiguration(
        isEnabled: true,
        wakeAction: .turnOn,
        sleepAction: .turnOff,
        powerOffAction: .turnOff
    )

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

struct HomeKitControllableDevice: Identifiable, Equatable {
    var id: String
    var displayName: String
    var homeName: String
    var roomName: String
    var accessoryIdentifier: UUID
    var serviceIdentifier: UUID
    var characteristicIdentifier: UUID
    var configuration: HomeKitDeviceActionConfiguration
}

@MainActor
final class HomeKitDeviceStore: NSObject, ObservableObject {
    @Published private(set) var authorizationState: String = "-"
    @Published private(set) var devices: [HomeKitControllableDevice] = []
    @Published var selectedDeviceID: String?

    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "HomeKitDeviceStore")
    private let manager = HMHomeManager()
    private let defaults: UserDefaults
    private var configurations: [String: HomeKitDeviceActionConfiguration]

    private enum Key {
        static let configurations = "homekit.deviceConfigurations"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: Key.configurations),
            let decoded = try? JSONDecoder().decode([String: HomeKitDeviceActionConfiguration].self, from: data)
        {
            configurations = decoded
        } else {
            configurations = [:]
        }
        super.init()
        manager.delegate = self
    }

    func start() {
        refreshDevices()
    }

    func refreshDevices() {
        authorizationState = homesStatus
        devices = discoverDevices()
        logHomeKitSnapshot()
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            selectedDeviceID = devices.first?.id
        }
    }

    func selectFirstDevice() {
        selectedDeviceID = devices.first?.id
    }

    func update(_ device: HomeKitControllableDevice) {
        configurations[device.id] = device.configuration
        saveConfigurations()
        refreshDevices()
        selectedDeviceID = device.id
    }

    func binding(for deviceID: String) -> Binding<HomeKitControllableDevice>? {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return nil }
        return Binding(
            get: { self.devices[index] },
            set: { self.update($0) }
        )
    }

    func apply(_ event: PowerEvent) async throws {
        let requests = devices.compactMap { device -> (HomeKitControllableDevice, DevicePowerState)? in
            guard device.configuration.isEnabled else { return nil }
            guard let state = device.configuration.action(for: event).requestedState else { return nil }
            return (device, state)
        }

        logger.info("Applying HomeKit event: reason=\(event.reason.rawValue, privacy: .public), requests=\(requests.count, privacy: .public)")

        for (device, state) in requests {
            try await setPower(state, for: device)
        }
    }

    private func discoverDevices() -> [HomeKitControllableDevice] {
        var discovered: [HomeKitControllableDevice] = []

        for home in manager.homes {
            for accessory in home.accessories {
                for service in accessory.services {
                    guard let power = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else { continue }
                    let id = Self.deviceID(accessory: accessory, service: service, characteristic: power)

                    discovered.append(
                        HomeKitControllableDevice(
                            id: id,
                            displayName: accessory.name,
                            homeName: home.name,
                            roomName: roomName(for: accessory, in: home),
                            accessoryIdentifier: accessory.uniqueIdentifier,
                            serviceIdentifier: service.uniqueIdentifier,
                            characteristicIdentifier: power.uniqueIdentifier,
                            configuration: configurations[id] ?? .defaultValue
                        )
                    )
                }
            }
        }

        return discovered.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func logHomeKitSnapshot() {
        let homes = manager.homes
        let accessoryCount = homes.reduce(0) { count, home in
            count + home.accessories.count
        }
        let serviceCount = homes.reduce(0) { count, home in
            count + home.accessories.reduce(0) { $0 + $1.services.count }
        }
        let powerCharacteristicCount = homes.reduce(0) { count, home in
            count + home.accessories.reduce(0) { accessoryCount, accessory in
                accessoryCount + accessory.services.reduce(0) { serviceCount, service in
                    serviceCount + service.characteristics.filter { $0.characteristicType == HMCharacteristicTypePowerState }.count
                }
            }
        }

        logger.info(
            "HomeKit snapshot: homes=\(homes.count, privacy: .public), accessories=\(accessoryCount, privacy: .public), services=\(serviceCount, privacy: .public), powerCharacteristics=\(powerCharacteristicCount, privacy: .public), controllableDevices=\(self.devices.count, privacy: .public)"
        )
    }

    private func setPower(_ state: DevicePowerState, for device: HomeKitControllableDevice) async throws {
        guard let characteristic = characteristic(for: device) else {
            logger.error("HomeKit device not found: device=\(device.displayName, privacy: .public)")
            throw HomeKitDeviceStoreError.deviceNotFound
        }

        logger.info("Writing HomeKit power state: device=\(device.displayName, privacy: .public), room=\(device.roomName, privacy: .public), state=\(state.rawValue, privacy: .public)")

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                characteristic.writeValue(NSNumber(value: state == .on), completionHandler: { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                })
            }
            logger.info("HomeKit power write succeeded: device=\(device.displayName, privacy: .public), state=\(state.rawValue, privacy: .public)")
        } catch {
            logger.error("HomeKit power write failed: device=\(device.displayName, privacy: .public), state=\(state.rawValue, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func characteristic(for device: HomeKitControllableDevice) -> HMCharacteristic? {
        for home in manager.homes {
            for accessory in home.accessories where accessory.uniqueIdentifier == device.accessoryIdentifier {
                for service in accessory.services where service.uniqueIdentifier == device.serviceIdentifier {
                    if let characteristic = service.characteristics.first(where: { $0.uniqueIdentifier == device.characteristicIdentifier }) {
                        return characteristic
                    }
                }
            }
        }
        return nil
    }

    private func roomName(for accessory: HMAccessory, in home: HMHome) -> String {
        for room in home.rooms where room.accessories.contains(where: { $0.uniqueIdentifier == accessory.uniqueIdentifier }) {
            return room.name
        }
        return "-"
    }

    private var homesStatus: String {
        if manager.homes.isEmpty {
            String(localized: "homekit.status.noHomes")
        } else {
            String(format: String(localized: "homekit.status.homeCount"), manager.homes.count)
        }
    }

    private func saveConfigurations() {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        defaults.set(data, forKey: Key.configurations)
    }

    private static func deviceID(accessory: HMAccessory, service: HMService, characteristic: HMCharacteristic) -> String {
        [
            accessory.uniqueIdentifier.uuidString,
            service.uniqueIdentifier.uuidString,
            characteristic.uniqueIdentifier.uuidString
        ].joined(separator: ":")
    }
}

extension HomeKitDeviceStore: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.refreshDevices()
        }
    }
}

enum HomeKitDeviceStoreError: LocalizedError {
    case deviceNotFound

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            String(localized: "homekit.error.deviceNotFound")
        }
    }
}
