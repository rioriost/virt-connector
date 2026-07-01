import AppKit
import Foundation
import OSLog

final class VirtConnectorPowerHelperApp: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "PowerHelper")
    private let relay = PowerEventRelay()
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else {
            logger.error("Another power helper instance is already running; terminating duplicate")
            NSApp.terminate(nil)
            return
        }

        startWorkspaceMonitor()
        logger.info("VirtConnector power helper started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopWorkspaceMonitor()
    }

    private func ensureSingleInstance() -> Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningHelpers = NSRunningApplication.runningApplications(withBundleIdentifier: "st.rio.virt-connector.PowerHelper")
        return !runningHelpers.contains { $0.processIdentifier != currentPID }
    }

    private func startWorkspaceMonitor() {
        guard workspaceObservers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { [weak self] _ in
                self?.handleSleep()
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] _ in
                self?.handleWake()
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: nil) { [weak self] _ in
                self?.handlePowerOff()
            }
        )
        logger.info("Workspace power monitor started")
    }

    private func stopWorkspaceMonitor() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func handleSleep() {
        logger.info("Received willSleep")
        let acknowledged = relay.send(.sleep, waitsForAcknowledgement: true)
        if !acknowledged {
            logger.error("Timed out waiting for app acknowledgement: event=sleep")
        }
    }

    private func handleWake() {
        logger.info("Received didWake")
        _ = relay.send(.wake, waitsForAcknowledgement: false)
    }

    private func handlePowerOff() {
        logger.info("Received willPowerOff")
        _ = NSWorkspace.shared.extendPowerOff(by: 8_000)
        let acknowledged = relay.send(.powerOff, waitsForAcknowledgement: true)
        if !acknowledged {
            logger.error("Timed out waiting for app acknowledgement: event=powerOff")
        }
    }
}
