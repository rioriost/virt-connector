import AppKit
import Foundation
import IOKit
import IOKit.pwr_mgt
import OSLog

final class VirtConnectorPowerHelperApp: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "PowerHelper")
    private let relay = PowerEventRelay()
    private var notificationPort: IONotificationPortRef?
    private var notifier = io_object_t()
    private var rootPort = io_connect_t()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var sleepEventSentForCycle = false

    private static let messageCanSystemSleep = ioKitCommonMessage(0x270)
    private static let messageSystemWillSleep = ioKitCommonMessage(0x280)
    private static let messageSystemHasPoweredOn = ioKitCommonMessage(0x300)

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else {
            logger.error("Another power helper instance is already running; terminating duplicate")
            NSApp.terminate(nil)
            return
        }

        startPowerMonitor()
        startPowerOffMonitor()
        logger.notice("VirtConnector power helper started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPowerMonitor()
        stopPowerOffMonitor()
    }

    private func ensureSingleInstance() -> Bool {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningHelpers = NSRunningApplication.runningApplications(withBundleIdentifier: "st.rio.virt-connector.PowerHelper")
        return !runningHelpers.contains { $0.processIdentifier != currentPID }
    }

    private func startPowerMonitor() {
        rootPort = IORegisterForSystemPower(
            Unmanaged.passUnretained(self).toOpaque(),
            &notificationPort,
            { refcon, service, messageType, messageArgument in
                guard let refcon else { return }
                let helper = Unmanaged<VirtConnectorPowerHelperApp>.fromOpaque(refcon).takeUnretainedValue()
                helper.receivePowerMessage(service: service, messageType: messageType, messageArgument: messageArgument)
            },
            &notifier
        )

        guard rootPort != 0, let notificationPort else {
            logger.error("Failed to register for system power notifications")
            return
        }

        if let source = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            logger.notice("IOKit power monitor started")
        } else {
            logger.error("Failed to get system power notification run loop source")
        }
    }

    private func stopPowerMonitor() {
        if notifier != 0 {
            IODeregisterForSystemPower(&notifier)
            notifier = 0
        }
        if let notificationPort {
            if let source = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue() {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
        if rootPort != 0 {
            IOServiceClose(rootPort)
            rootPort = 0
        }
    }

    private func startPowerOffMonitor() {
        guard workspaceObservers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
                self?.handlePowerOff()
            }
        )
    }

    private func stopPowerOffMonitor() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func receivePowerMessage(service: io_service_t, messageType: UInt32, messageArgument: UnsafeMutableRawPointer?) {
        switch messageType {
        case Self.messageCanSystemSleep:
            logger.notice("Received canSystemSleep")
            sendSleepIfNeeded(acknowledgementTimeout: 8)
            acknowledgePowerChange(messageArgument: messageArgument, eventName: "canSystemSleep")
        case Self.messageSystemWillSleep:
            logger.notice("Received systemWillSleep")
            sendSleepIfNeeded(acknowledgementTimeout: 2)
            acknowledgePowerChange(messageArgument: messageArgument, eventName: "systemWillSleep")
        case Self.messageSystemHasPoweredOn:
            logger.notice("Received systemHasPoweredOn")
            sleepEventSentForCycle = false
            _ = relay.send(.wake, waitsForAcknowledgement: false)
        default:
            break
        }
    }

    private func sendSleepIfNeeded(acknowledgementTimeout: TimeInterval) {
        guard !sleepEventSentForCycle else { return }
        sleepEventSentForCycle = true
        let acknowledged = relay.send(.sleep, waitsForAcknowledgement: true, acknowledgementTimeout: acknowledgementTimeout)
        if !acknowledged {
            logger.error("Timed out waiting for app acknowledgement: event=sleep")
        }
    }

    private func handlePowerOff() {
        logger.notice("Received willPowerOff")
        _ = NSWorkspace.shared.extendPowerOff(by: 8_000)
        let acknowledged = relay.send(.powerOff, waitsForAcknowledgement: true)
        if !acknowledged {
            logger.error("Timed out waiting for app acknowledgement: event=powerOff")
        }
    }

    private func acknowledgePowerChange(messageArgument: UnsafeMutableRawPointer?, eventName: String) {
        guard let notificationID = Self.notificationID(from: messageArgument) else {
            logger.error("Received \(eventName, privacy: .public) without notification ID")
            return
        }
        let result = IOAllowPowerChange(rootPort, notificationID)
        logger.notice("Acknowledged \(eventName, privacy: .public): result=\(result, privacy: .public)")
    }

    private static func ioKitCommonMessage(_ message: UInt32) -> UInt32 {
        let sysIOKit = UInt32(0x38000000)
        let subIOKitCommon = UInt32(0x00000000)
        return sysIOKit | subIOKitCommon | message
    }

    private static func notificationID(from messageArgument: UnsafeMutableRawPointer?) -> intptr_t? {
        guard let messageArgument else { return nil }
        return intptr_t(bitPattern: messageArgument)
    }
}
