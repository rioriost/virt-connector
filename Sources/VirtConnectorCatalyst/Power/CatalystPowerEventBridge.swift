import Foundation
import OSLog

@MainActor
final class CatalystPowerEventBridge: NSObject {
    private let logger = Logger(subsystem: "st.rio.virt-connector", category: "CatalystPowerEventBridge")
    private let center = DistributedNotificationCenter.default()
    private var handler: (@Sendable (PowerEvent) async -> Void)?
    private var isStarted = false

    func start(handler: @Sendable @escaping (PowerEvent) async -> Void) {
        guard !isStarted else { return }
        self.handler = handler
        center.addObserver(
            self,
            selector: #selector(receive(_:)),
            name: .virtConnectorPowerEvent,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        isStarted = true
        logger.info("Catalyst power event bridge started")
    }

    func stop() {
        guard isStarted else { return }
        center.removeObserver(self)
        handler = nil
        isStarted = false
    }

    @objc private func receive(_ notification: Notification) {
        guard let rawEvent = notification.userInfo?[PowerEventNotificationKey.event] as? String else {
            logger.error("Received helper power event without event name")
            return
        }
        guard let event = PowerEvent(helperRawValue: rawEvent) else {
            logger.error("Received unknown helper power event: event=\(rawEvent, privacy: .public)")
            return
        }

        let eventID = notification.userInfo?[PowerEventNotificationKey.id] as? String
        logger.info("Received helper power event: event=\(rawEvent, privacy: .public), id=\(eventID ?? "-", privacy: .public)")

        Task { @MainActor in
            await handler?(event)
            if let eventID {
                acknowledge(eventID: eventID)
            }
        }
    }

    private func acknowledge(eventID: String) {
        center.postNotificationName(
            .virtConnectorPowerEventAcknowledgement,
            object: nil,
            userInfo: [PowerEventNotificationKey.id: eventID],
            deliverImmediately: true
        )
        logger.info("Acknowledged helper power event: id=\(eventID, privacy: .public)")
    }
}

private extension PowerEvent {
    init?(helperRawValue: String) {
        switch helperRawValue {
        case "wake":
            self = .wake
        case "sleep":
            self = .sleep
        case "powerOff":
            self = .powerOff
        default:
            return nil
        }
    }
}

private enum PowerEventNotificationKey {
    static let event = "event"
    static let id = "id"
}

private extension Notification.Name {
    static let virtConnectorPowerEvent = Notification.Name("st.rio.virt-connector.power-event")
    static let virtConnectorPowerEventAcknowledgement = Notification.Name("st.rio.virt-connector.power-event-ack")
}
