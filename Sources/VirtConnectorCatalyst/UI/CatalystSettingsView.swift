import SwiftUI

struct CatalystSettingsView: View {
    @ObservedObject var model: CatalystAppModel
    @ObservedObject private var homeStore: HomeKitDeviceStore
    @ObservedObject private var loginItemManager: CatalystLoginItemManager
    @State private var selectedTab: SettingsTab = .general

    init(model: CatalystAppModel) {
        self._model = ObservedObject(wrappedValue: model)
        self._homeStore = ObservedObject(wrappedValue: model.homeStore)
        self._loginItemManager = ObservedObject(wrappedValue: model.loginItemManager)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalView
                .tabItem { Text(String(localized: "settings.tab.general")) }
                .tag(SettingsTab.general)

            devicesView
                .tabItem { Text(String(localized: "settings.tab.devices")) }
                .tag(SettingsTab.devices)
        }
        .padding(16)
        .onChange(of: selectedTab) { _, value in
            if value == .devices {
                homeStore.selectFirstDevice()
            }
        }
    }

    private var generalView: some View {
        Form {
            Section {
                Toggle(
                    String(localized: "settings.launchAtLogin"),
                    isOn: Binding(
                        get: { loginItemManager.isEnabled },
                        set: { loginItemManager.setEnabled($0) }
                    )
                )
                .toggleStyle(.switch)

                if let errorMessage = loginItemManager.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Toggle(String(localized: "settings.monitoring.enabled"), isOn: $model.isMonitoringEnabled)
                    .toggleStyle(.switch)
                Text(String(localized: "settings.monitoring.note"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section(String(localized: "homekit.section")) {
                LabeledContent(String(localized: "homekit.status"), value: homeStore.authorizationState)
                Button(String(localized: "homekit.refresh")) {
                    model.refreshHomes()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var devicesView: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                List(selection: selectedDeviceBinding) {
                    ForEach(homeStore.devices) { device in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.displayName)
                                .lineLimit(1)
                            Text("\(device.homeName) / \(device.roomName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(device.id)
                    }
                }
                .frame(width: 240)

                HStack {
                    Button {
                        model.refreshHomes()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(String(localized: "homekit.refresh"))

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            Divider()

            Form {
                selectedDeviceSection
                statusSection
            }
            .formStyle(.grouped)
            .padding(16)
        }
    }

    @ViewBuilder
    private var selectedDeviceSection: some View {
        Section(String(localized: "settings.device.section")) {
            if let selectedDeviceID = homeStore.selectedDeviceID, let device = homeStore.binding(for: selectedDeviceID) {
                LabeledContent(String(localized: "settings.device.name"), value: device.wrappedValue.displayName)
                LabeledContent(String(localized: "homekit.home"), value: device.wrappedValue.homeName)
                LabeledContent(String(localized: "homekit.room"), value: device.wrappedValue.roomName)

                Toggle(String(localized: "settings.device.enabled"), isOn: device.configuration.isEnabled)

                Picker(String(localized: "settings.events.wake"), selection: device.configuration.wakeAction) {
                    ForEach(PowerEventAction.allCases) { action in
                        Text(action.localizedTitle).tag(action)
                    }
                }

                Picker(String(localized: "settings.events.sleep"), selection: device.configuration.sleepAction) {
                    ForEach(PowerEventAction.allCases) { action in
                        Text(action.localizedTitle).tag(action)
                    }
                }

                Picker(String(localized: "settings.events.powerOff"), selection: device.configuration.powerOffAction) {
                    ForEach(PowerEventAction.allCases) { action in
                        Text(action.localizedTitle).tag(action)
                    }
                }
            } else {
                Text(String(localized: "homekit.noDevices"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusSection: some View {
        Section(String(localized: "settings.status.section")) {
            LabeledContent(String(localized: "settings.status.lastReason"), value: model.lastTriggerReason)
            LabeledContent(String(localized: "settings.status.lastDate"), value: formattedLastRequestDate)
            LabeledContent(String(localized: "settings.status.lastError"), value: model.lastErrorMessage)
        }
    }

    private var formattedLastRequestDate: String {
        guard let date = model.lastRequestDate else { return "-" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private var selectedDeviceBinding: Binding<String?> {
        Binding(
            get: { homeStore.selectedDeviceID },
            set: { homeStore.selectedDeviceID = $0 }
        )
    }
}

private enum SettingsTab {
    case general
    case devices
}
