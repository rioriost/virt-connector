import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItemManager: LoginItemManager

    var body: some View {
        Form {
            Section {
                Toggle(
                    String(localized: "settings.launchAtLogin"),
                    isOn: Binding(
                        get: { loginItemManager.isEnabled },
                        set: { loginItemManager.setEnabled($0) }
                    )
                )
                if let errorMessage = loginItemManager.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section(String(localized: "settings.device.section")) {
                TextField(String(localized: "settings.device.nodeID"), text: $settings.nodeID)
                TextField(String(localized: "settings.device.endpointID"), text: $settings.endpointID)
                if !settings.matterDeviceConfiguration.isConfigured {
                    Text(String(localized: "settings.device.validation"))
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Text(String(localized: "settings.device.note"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section(String(localized: "settings.events.section")) {
                Toggle(String(localized: "settings.events.wake"), isOn: $settings.enableWake)
                Toggle(String(localized: "settings.events.sleep"), isOn: $settings.enableSleep)
                Toggle(String(localized: "settings.events.powerOff"), isOn: $settings.enablePowerOff)
            }

            Section(String(localized: "settings.status.section")) {
                LabeledContent(String(localized: "settings.status.lastState"), value: settings.lastRequestedPowerState)
                LabeledContent(String(localized: "settings.status.lastReason"), value: settings.lastTriggerReason)
                LabeledContent(String(localized: "settings.status.lastDate"), value: formattedLastRequestDate)
                LabeledContent(String(localized: "settings.status.lastError"), value: settings.lastErrorMessage)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460, height: 420)
    }

    private var formattedLastRequestDate: String {
        guard let date = settings.lastRequestDate else { return "-" }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}
