import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItemManager: LoginItemManager

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                List(selection: $settings.selectedDeviceID) {
                    ForEach(settings.devices) { device in
                        DeviceRow(device: device)
                            .tag(device.id)
                    }
                }
                .frame(width: 210)

                HStack {
                    Button {
                        settings.addDevice()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(String(localized: "settings.device.add"))

                    Button {
                        settings.removeSelectedDevice()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(settings.selectedDeviceID == nil || settings.devices.isEmpty)
                    .help(String(localized: "settings.device.remove"))

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Form {
                launchSection
                selectedDeviceSection
                eventMonitorSection
                statusSection
            }
            .formStyle(.grouped)
            .padding(16)
        }
        .frame(width: 760, height: 560)
    }

    private var launchSection: some View {
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
    }

    @ViewBuilder
    private var selectedDeviceSection: some View {
        Section(String(localized: "settings.device.section")) {
            if let selectedDeviceID = settings.selectedDeviceID, let device = settings.binding(for: selectedDeviceID) {
                TextField(String(localized: "settings.device.name"), text: device.displayName)
                TextField(String(localized: "settings.device.nodeID"), text: device.nodeID)
                TextField(String(localized: "settings.device.endpointID"), text: device.endpointID)
                Toggle(String(localized: "settings.device.enabled"), isOn: device.isEnabled)

                Picker(String(localized: "settings.events.wake"), selection: device.wakeAction) {
                    ForEach(PowerEventAction.allCases) { action in
                        Text(action.localizedTitle).tag(action)
                    }
                }

                Picker(String(localized: "settings.events.sleep"), selection: device.sleepAction) {
                    ForEach(PowerEventAction.allCases) { action in
                        Text(action.localizedTitle).tag(action)
                    }
                }

                Picker(String(localized: "settings.events.powerOff"), selection: device.powerOffAction) {
                    ForEach(PowerEventAction.allCases) { action in
                        Text(action.localizedTitle).tag(action)
                    }
                }

                if !device.wrappedValue.matterConfiguration.isConfigured {
                    Text(String(localized: "settings.device.validation"))
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Text(String(localized: "settings.device.note"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Text(String(localized: "settings.device.empty"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var eventMonitorSection: some View {
        Section(String(localized: "settings.events.section")) {
            Toggle(String(localized: "settings.events.enableWake"), isOn: $settings.enableWake)
            Toggle(String(localized: "settings.events.enableSleep"), isOn: $settings.enableSleep)
            Toggle(String(localized: "settings.events.enablePowerOff"), isOn: $settings.enablePowerOff)
        }
    }

    private var statusSection: some View {
        Section(String(localized: "settings.status.section")) {
            LabeledContent(String(localized: "settings.status.lastState"), value: settings.lastRequestedPowerState)
            LabeledContent(String(localized: "settings.status.lastReason"), value: settings.lastTriggerReason)
            LabeledContent(String(localized: "settings.status.lastDate"), value: formattedLastRequestDate)
            LabeledContent(String(localized: "settings.status.lastError"), value: settings.lastErrorMessage)
        }
    }

    private var formattedLastRequestDate: String {
        guard let date = settings.lastRequestDate else { return "-" }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}

private struct DeviceRow: View {
    let device: ManagedMatterDevice

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.isEnabled ? "lightbulb" : "lightbulb.slash")
                .foregroundStyle(device.isEnabled ? .yellow : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName.isEmpty ? String(localized: "settings.device.untitled") : device.displayName)
                    .lineLimit(1)
                Text(device.matterConfiguration.isConfigured ? "Node \(device.nodeID)" : String(localized: "settings.device.notConfigured"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
