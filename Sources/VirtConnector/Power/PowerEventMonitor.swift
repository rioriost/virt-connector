import AppKit
import Foundation
import OSLog

@MainActor
final class PowerEventMonitor {
    private let settings: AppSettings
    private let handler: (PowerEvent) async -> Void
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "PowerEventMonitor")
    private var observers: [NSObjectProtocol] = []

    init(settings: AppSettings, handler: @escaping (PowerEvent) async -> Void) {
        self.settings = settings
        self.handler = handler
    }

    func start() {
        guard observers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.dispatch(.wake)
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await self?.dispatch(.sleep)
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dispatchPowerOffSynchronously()
            }
        })

        logger.info("Power event monitor started")
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }

    private func dispatch(_ event: PowerEvent) async {
        guard isEnabled(event) else { return }
        await handler(event)
    }

    private func dispatchPowerOffSynchronously() {
        guard settings.enablePowerOff else { return }

        _ = NSWorkspace.shared.extendPowerOff(by: 5_000)
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            await handler(.powerOff)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 4)
    }

    private func isEnabled(_ event: PowerEvent) -> Bool {
        switch event {
        case .wake:
            settings.enableWake
        case .sleep:
            settings.enableSleep
        case .powerOff:
            settings.enablePowerOff
        }
    }
}
