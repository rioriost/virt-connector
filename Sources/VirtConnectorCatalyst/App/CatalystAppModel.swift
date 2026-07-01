import Foundation

@MainActor
final class CatalystAppModel: ObservableObject {
    @Published var isMonitoringEnabled: Bool {
        didSet { defaults.set(isMonitoringEnabled, forKey: Key.isMonitoringEnabled) }
    }

    @Published private(set) var lastTriggerReason: String = "-"
    @Published private(set) var lastRequestDate: Date?
    @Published private(set) var lastErrorMessage: String = "-"

    let homeStore = HomeKitDeviceStore()
    let loginItemManager = CatalystLoginItemManager()
    private let defaults: UserDefaults
    private let powerMonitor: CatalystPowerEventMonitor

    private enum Key {
        static let isMonitoringEnabled = "catalyst.monitoring.isEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.isMonitoringEnabled) == nil {
            defaults.set(true, forKey: Key.isMonitoringEnabled)
        }
        isMonitoringEnabled = defaults.bool(forKey: Key.isMonitoringEnabled)
        powerMonitor = CatalystPowerEventMonitor()
    }

    func start() {
        homeStore.start()
        powerMonitor.start { [weak self] event in
            Task { @MainActor in
                await self?.handle(event)
            }
        }
    }

    func refreshHomes() {
        homeStore.refreshDevices()
    }

    private func handle(_ event: PowerEvent) async {
        lastTriggerReason = event.reason.rawValue
        lastRequestDate = Date()

        guard isMonitoringEnabled else {
            lastErrorMessage = "-"
            return
        }

        do {
            try await homeStore.apply(event)
            lastErrorMessage = "-"
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
