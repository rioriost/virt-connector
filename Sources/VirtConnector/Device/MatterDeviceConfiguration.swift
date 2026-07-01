import Foundation

struct MatterDeviceConfiguration: Equatable {
    var nodeID: String
    var endpointID: String

    var isConfigured: Bool {
        !nodeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !endpointID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
