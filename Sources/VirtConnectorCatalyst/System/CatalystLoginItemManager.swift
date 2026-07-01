import Foundation
import ServiceManagement

@MainActor
final class CatalystLoginItemManager: ObservableObject {
    @Published private(set) var errorMessage: String?
    private let helper = SMAppService.loginItem(identifier: "st.rio.virt-connector.PowerHelper")
    private let mainApp = SMAppService.mainApp

    var isEnabled: Bool {
        mainApp.status == .enabled && helper.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if mainApp.status != .enabled {
                    try mainApp.register()
                }
                if helper.status != .enabled {
                    try helper.register()
                }
            } else {
                if helper.status == .enabled {
                    try helper.unregister()
                }
                if mainApp.status == .enabled {
                    try mainApp.unregister()
                }
            }
            errorMessage = nil
            objectWillChange.send()
        } catch {
            errorMessage = error.localizedDescription
            objectWillChange.send()
        }
    }
}
