import Foundation
import IOKit
import IOKit.pwr_mgt
import OSLog
import UIKit

final class CatalystPowerEventMonitor {
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "CatalystPowerEventMonitor")
    private var notificationPort: IONotificationPortRef?
    private var notifier = io_object_t()
    private var rootPort = io_connect_t()
    private var terminationObserver: NSObjectProtocol?
    private var handler: (@Sendable (PowerEvent) -> Void)?

    private static let messageSystemWillSleep = ioKitCommonMessage(0x280)
    private static let messageSystemHasPoweredOn = ioKitCommonMessage(0x300)

    func start(handler: @Sendable @escaping (PowerEvent) -> Void) {
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

        IONotificationPortSetDispatchQueue(notificationPort, .main)
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
        rootPort = 0

        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
    }

    private func receive(service: io_service_t, messageType: UInt32, messageArgument: UnsafeMutableRawPointer?) {
        switch messageType {
        case Self.messageSystemWillSleep:
            if let messageArgument {
                IOAllowPowerChange(rootPort, intptr_t(bitPattern: messageArgument))
            }
            handler?(.sleep)
        case Self.messageSystemHasPoweredOn:
            handler?(.wake)
        default:
            break
        }
    }

    private static func ioKitCommonMessage(_ message: UInt32) -> UInt32 {
        let sysIOKit = UInt32(0x38000000)
        let subIOKitCommon = UInt32(0x00000000)
        return sysIOKit | subIOKitCommon | message
    }

    private func registerTerminationObserver() {
        guard terminationObserver == nil else { return }
        let powerOffHandler = handler
        terminationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            powerOffHandler?(.powerOff)
        }
    }
}
