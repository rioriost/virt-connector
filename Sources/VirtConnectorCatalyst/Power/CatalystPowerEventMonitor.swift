import Foundation
import IOKit
import IOKit.pwr_mgt
import OSLog
import UIKit

final class CatalystPowerEventMonitor: @unchecked Sendable {
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "CatalystPowerEventMonitor")
    private let queue = DispatchQueue(label: "st.rio.virt-connector.power-events")
    private let sleepHandlerTimeout: Duration = .seconds(10)
    private var notificationPort: IONotificationPortRef?
    private var notifier = io_object_t()
    private var rootPort = io_connect_t()
    private var terminationObserver: NSObjectProtocol?
    private var handler: (@Sendable (PowerEvent) async -> Void)?

    private static let messageCanSystemSleep = ioKitCommonMessage(0x270)
    private static let messageSystemWillSleep = ioKitCommonMessage(0x280)
    private static let messageSystemHasPoweredOn = ioKitCommonMessage(0x300)

    func start(handler: @Sendable @escaping (PowerEvent) async -> Void) {
        guard rootPort == 0 else { return }
        self.handler = handler
        registerTerminationObserver()

        rootPort = IORegisterForSystemPower(
            Unmanaged.passUnretained(self).toOpaque(),
            &notificationPort,
            { refcon, service, messageType, messageArgument in
                guard let refcon else { return }
                let monitor = Unmanaged<CatalystPowerEventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.receive(service: service, messageType: messageType, messageArgument: messageArgument)
            },
            &notifier
        )

        guard rootPort != 0, let notificationPort else {
            logger.error("Failed to register for IOKit power notifications")
            return
        }

        IONotificationPortSetDispatchQueue(notificationPort, queue)
        logger.info("Catalyst power event monitor started")
    }

    func stop() {
        if notifier != 0 {
            IODeregisterForSystemPower(&notifier)
            notifier = 0
        }
        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
        if rootPort != 0 {
            IOServiceClose(rootPort)
        }
        rootPort = 0

        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
    }

    private func receive(service: io_service_t, messageType: UInt32, messageArgument: UnsafeMutableRawPointer?) {
        switch messageType {
        case Self.messageCanSystemSleep:
            allowPowerChange(messageArgument: messageArgument, eventName: "canSystemSleep")
        case Self.messageSystemWillSleep:
            guard let notificationID = Self.notificationID(from: messageArgument) else {
                logger.error("Received systemWillSleep without notification ID")
                return
            }
            let kernelPort = rootPort
            logger.info("Received systemWillSleep; applying configured actions before acknowledging sleep")
            Task {
                let completed = await self.runHandler(for: .sleep, timeout: self.sleepHandlerTimeout)
                if !completed {
                    self.logger.error("Sleep handler timed out before power acknowledgement")
                }
                let result = IOAllowPowerChange(kernelPort, notificationID)
                self.logger.info("Acknowledged systemWillSleep: result=\(result, privacy: .public)")
            }
        case Self.messageSystemHasPoweredOn:
            logger.info("Received systemHasPoweredOn")
            Task {
                await self.runHandler(for: .wake)
            }
        default:
            logger.debug("Ignored IOKit power message: type=\(messageType, privacy: .public)")
            break
        }
    }

    private func allowPowerChange(messageArgument: UnsafeMutableRawPointer?, eventName: String) {
        guard let notificationID = Self.notificationID(from: messageArgument) else {
            logger.error("Received \(eventName, privacy: .public) without notification ID")
            return
        }
        let result = IOAllowPowerChange(rootPort, notificationID)
        logger.info("Acknowledged \(eventName, privacy: .public): result=\(result, privacy: .public)")
    }

    @discardableResult
    private func runHandler(for event: PowerEvent, timeout: Duration? = nil) async -> Bool {
        guard let handler else { return true }
        guard let timeout else {
            await handler(event)
            return true
        }

        let gate = ContinuationGate()
        return await withCheckedContinuation { continuation in
            Task {
                await handler(event)
                if gate.tryResume() {
                    continuation.resume(returning: true)
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if gate.tryResume() {
                    continuation.resume(returning: false)
                }
            }
        }
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

    private func registerTerminationObserver() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.runHandler(for: .powerOff)
            }
        }
    }
}

private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return false }
        didResume = true
        return true
    }
}
