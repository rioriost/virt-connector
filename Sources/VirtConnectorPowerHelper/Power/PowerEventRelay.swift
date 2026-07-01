import Foundation
import OSLog

enum HelperPowerEvent: String {
    case wake
    case sleep
    case powerOff
}

final class PowerEventRelay {
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "PowerEventRelay")
    private let center = DistributedNotificationCenter.default()
    private let acknowledgementTimeout: TimeInterval = 8

    func send(_ event: HelperPowerEvent, waitsForAcknowledgement: Bool) -> Bool {
        let eventID = UUID().uuidString
        let waiter = waitsForAcknowledgement ? AcknowledgementWaiter(eventID: eventID) : nil

        if let waiter {
            center.addObserver(
                waiter,
                selector: #selector(AcknowledgementWaiter.receive(_:)),
                name: .virtConnectorPowerEventAcknowledgement,
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }

        logger.info("Posting power event: event=\(event.rawValue, privacy: .public), id=\(eventID, privacy: .public)")
        center.postNotificationName(
            .virtConnectorPowerEvent,
            object: nil,
            userInfo: [
                PowerEventNotificationKey.event: event.rawValue,
                PowerEventNotificationKey.id: eventID
            ],
            deliverImmediately: true
        )

        guard let waiter else { return true }
        let didAcknowledge = waiter.wait(timeout: acknowledgementTimeout)
        center.removeObserver(waiter)
        logger.info("Power event acknowledgement: event=\(event.rawValue, privacy: .public), id=\(eventID, privacy: .public), acknowledged=\(didAcknowledge, privacy: .public)")
        return didAcknowledge
    }
}

private final class AcknowledgementWaiter: NSObject {
    private let eventID: String
    private let semaphore = DispatchSemaphore(value: 0)
    private var didAcknowledge = false
    private let lock = NSLock()

    init(eventID: String) {
        self.eventID = eventID
    }

    @objc func receive(_ notification: Notification) {
        guard notification.userInfo?[PowerEventNotificationKey.id] as? String == eventID else { return }
        lock.lock()
        let shouldSignal = !didAcknowledge
        didAcknowledge = true
        lock.unlock()

        if shouldSignal {
            semaphore.signal()
        }
    }

    func wait(timeout: TimeInterval) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }
}

enum PowerEventNotificationKey {
    static let event = "event"
    static let id = "id"
}

extension Notification.Name {
    static let virtConnectorPowerEvent = Notification.Name("st.rio.virt-connector.power-event")
    static let virtConnectorPowerEventAcknowledgement = Notification.Name("st.rio.virt-connector.power-event-ack")
}
