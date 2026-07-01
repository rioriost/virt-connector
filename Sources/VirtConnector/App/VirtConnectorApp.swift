import SwiftUI

@main
struct VirtConnectorApp: App {
    @StateObject private var model = MenuBarAppModel()

    var body: some Scene {
        MenuBarExtra {
            Button(String(localized: "menu.turnOn")) {
                model.turnOn()
            }
            Button(String(localized: "menu.turnOff")) {
                model.turnOff()
            }
            Divider()
            Button(String(localized: "menu.settings")) {
                model.openSettings()
            }
            Divider()
            Button(String(localized: "menu.quit")) {
                model.quit()
            }
        } label: {
            Text("VC")
                .monospaced()
        }
        .menuBarExtraStyle(.menu)
    }
}
