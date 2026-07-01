import Foundation

struct MatterDeviceConfiguration: Equatable {
    var id: UUID
    var displayName: String
    var nodeID: String
    var endpointID: String

    init(id: UUID = UUID(), displayName: String = "", nodeID: String, endpointID: String) {
        self.id = id
        self.displayName = displayName
        self.nodeID = nodeID
        self.endpointID = endpointID
    }

    var isConfigured: Bool {
        parsedNodeID != nil && parsedEndpointID != nil
    }

    var parsedNodeID: UInt64? {
        UInt64(nodeID.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var parsedEndpointID: UInt16? {
        UInt16(endpointID.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
