import Foundation

struct MatterDeviceConfiguration: Equatable {
    var nodeID: String
    var endpointID: String

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
