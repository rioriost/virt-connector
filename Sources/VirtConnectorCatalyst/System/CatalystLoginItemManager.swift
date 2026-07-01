import Foundation
import ServiceManagement

@MainActor
final class CatalystLoginItemManager: ObservableObject {
    @Published private(set) var errorMessage: String?

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
            objectWillChange.send()
        }
    }
}
