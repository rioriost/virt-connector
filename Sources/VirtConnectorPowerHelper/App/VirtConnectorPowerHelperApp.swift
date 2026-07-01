import AppKit
import Foundation
import OSLog

final class VirtConnectorPowerHelperApp: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "PowerHelper")
    private let relay = PowerEventRelay()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastEvent: HelperPowerEvent?
    private var lastEventDate = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else {
            logger.error("Another power helper instance is already running; terminating duplicate")
            NSApp.terminate(nil)
            return
        }

        startWorkspaceMonitor()
        logger.notice("VirtConnector power helper started")
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
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handlePreSleep()
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handleWillSleepFallback()
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handleWake(source: "didWake")
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handleWake(source: "screensDidWake")
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handlePowerOff()
            }
        )
        logger.notice("Workspace power monitor started")
    }

    private func stopWorkspaceMonitor() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func handlePreSleep() {
        logger.notice("Received screensDidSleep")
        send(.sleep, waitsForAcknowledgement: true, acknowledgementTimeout: 8, deduplicationWindow: 10)
    }

    private func handleWillSleepFallback() {
        logger.notice("Received willSleep")
        send(.sleep, waitsForAcknowledgement: false, acknowledgementTimeout: 0, deduplicationWindow: 10)
    }

    private func handleWake(source: String) {
        logger.notice("Received \(source, privacy: .public)")
        send(.wake, waitsForAcknowledgement: false, acknowledgementTimeout: 0, deduplicationWindow: 3)
    }

    private func handlePowerOff() {
        logger.notice("Received willPowerOff")
        _ = NSWorkspace.shared.extendPowerOff(by: 8_000)
        send(.powerOff, waitsForAcknowledgement: true, acknowledgementTimeout: 8, deduplicationWindow: 10)
    }

    private func send(
        _ event: HelperPowerEvent,
        waitsForAcknowledgement: Bool,
        acknowledgementTimeout: TimeInterval,
        deduplicationWindow: TimeInterval
    ) {
        let now = Date()
        if lastEvent == event, now.timeIntervalSince(lastEventDate) < deduplicationWindow {
            logger.notice("Skipped duplicate power event: event=\(event.rawValue, privacy: .public)")
            return
        }

        lastEvent = event
        lastEventDate = now
        let acknowledged = relay.send(
            event,
            waitsForAcknowledgement: waitsForAcknowledgement,
            acknowledgementTimeout: acknowledgementTimeout
        )
        if !acknowledged {
            logger.error("Timed out waiting for app acknowledgement: event=\(event.rawValue, privacy: .public)")
            lastEvent = nil
            lastEventDate = .distantPast
        }
    }
}
