import Foundation
import OSLog

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
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "CatalystAppModel")
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
            await self?.handle(event)
        }
    }

    func refreshHomes() {
        homeStore.refreshDevices()
    }

    private func handle(_ event: PowerEvent) async {
        lastTriggerReason = event.reason.rawValue
        lastRequestDate = Date()
        logger.info("Handling power event: reason=\(event.reason.rawValue, privacy: .public), monitoringEnabled=\(self.isMonitoringEnabled, privacy: .public)")

        guard isMonitoringEnabled else {
            lastErrorMessage = "-"
            logger.info("Skipped power event because monitoring is disabled")
            return
        }

        do {
            try await homeStore.apply(event)
            lastErrorMessage = "-"
            logger.info("Completed power event: reason=\(event.reason.rawValue, privacy: .public)")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("Failed power event: reason=\(event.reason.rawValue, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
        }
    }
}
