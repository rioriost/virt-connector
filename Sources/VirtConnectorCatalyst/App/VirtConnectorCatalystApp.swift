import SwiftUI

@main
struct VirtConnectorCatalystApp: App {
    @StateObject private var model = CatalystAppModel()

    var body: some Scene {
        WindowGroup {
            CatalystSettingsView(model: model)
                .frame(minWidth: 760, minHeight: 560)
                .task {
                    model.start()
                }
        }
    }
}
