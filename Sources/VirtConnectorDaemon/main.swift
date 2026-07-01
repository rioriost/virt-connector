import AppKit
import Foundation
import VirtConnectorCore

@main
final class VirtConnectorDaemon: NSObject, NSApplicationDelegate {
    private let configStore = ConfigStore()
    private let displayLogReader = DisplayLogReader()
    private let log = FileLog.daemonLog()
    private lazy var executor = ActionExecutor(log: log)
    private lazy var shutdownPerformer = ShutdownPerformer(
        configStore: configStore,
        actionExecutor: executor,
        log: log
    )

    private var lastDisplayEntryKey: String?
    private let pollQueue = DispatchQueue(label: "st.rio.virt-connectord.pmset-poll", qos: .utility)
    private var pollTimer: DispatchSourceTimer?
    private var signalSources: [DispatchSourceSignal] = []
    private var powerOffHandled = false
    private var statusItem: NSStatusItem?
    private var shutdownMenuItem: NSMenuItem?
    private let localizer = AgentLocalizer()

    static func main() {
        let daemon = VirtConnectorDaemon()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = daemon
        daemon.start()
        app.run()
    }

    private func start() {
        log.write("virt-connectord starting")
        ProcessInfo.processInfo.disableSuddenTermination()
        log.write("NSApplication initialized with accessory activation policy")
        installStatusMenu()
        startDisplayPolling()
        observePowerOff()
        observeSignals()
        log.write("virt-connectord started")
    }

    private func startDisplayPolling() {
        let interval = max(configStore.loadOrDefault().pollIntervalSeconds, 1)
        pollQueue.async { [weak self] in
            guard let self else { return }

            self.seedLatestDisplayEntry()

            let timer = DispatchSource.makeTimerSource(queue: self.pollQueue)
            timer.schedule(deadline: .now() + interval, repeating: interval)
            timer.setEventHandler { [weak self] in
                self?.pollDisplayLog()
            }
            self.pollTimer = timer
            timer.resume()
            self.log.write("Started display polling on background queue with interval=\(Int(interval))s")
        }
    }

    private func seedLatestDisplayEntry() {
        do {
            let entry = try displayLogReader.latestDisplayEntry()
            lastDisplayEntryKey = entry?.key
            if let entry {
                log.write("Seeded display event \(entry.key): \(entry.rawLine)")
            } else {
                log.write("No display event found while seeding")
            }
        } catch {
            log.write("Failed to seed display event: \(error)")
        }
    }

    private func pollDisplayLog() {
        do {
            guard let entry = try displayLogReader.latestDisplayEntry() else {
                log.write("No display event found")
                return
            }

            guard entry.key != lastDisplayEntryKey else {
                return
            }

            lastDisplayEntryKey = entry.key
            log.write("Detected \(entry.trigger.rawValue): \(entry.rawLine)")
            execute(entry.trigger)
        } catch {
            log.write("Failed to poll display log: \(error)")
        }
    }

    private func observePowerOff() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePowerOff(reason: "NSWorkspace.willPowerOffNotification", shouldExit: false)
        }
    }

    private func observeSignals() {
        for signalNumber in [SIGTERM, SIGINT] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                self?.handlePowerOff(reason: "signal \(signalNumber)", shouldExit: true)
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func installStatusMenu() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 32)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = makeStatusImage()
            button.imagePosition = .imageOnly
            button.toolTip = "VirtConnector"
        }

        let menu = NSMenu()
        let shutdownItem = NSMenuItem(
            title: localizer.shutdownMenuTitle,
            action: #selector(confirmAndShutdown),
            keyEquivalent: ""
        )
        shutdownItem.target = self
        menu.addItem(shutdownItem)
        self.shutdownMenuItem = shutdownItem

        statusItem.menu = menu
        log.write("Installed status menu")
    }

    @objc private func confirmAndShutdown() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = localizer.shutdownDialogTitle
        alert.informativeText = localizer.shutdownDialogMessage
        alert.alertStyle = .warning
        alert.icon = makeShutdownAlertIcon()
        alert.addButton(withTitle: localizer.shutdownButtonTitle)
        alert.addButton(withTitle: localizer.cancelButtonTitle)

        guard alert.runModal() == .alertFirstButtonReturn else {
            log.write("Menu shutdown canceled")
            return
        }

        shutdownMenuItem?.isEnabled = false
        log.write("Menu shutdown requested")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let result = try self.shutdownPerformer.perform()
                self.log.write("Menu shutdown action completed: attempted=\(result.attempted) failed=\(result.failed)")
            } catch {
                self.log.write("Menu shutdown failed: \(error)")
                DispatchQueue.main.async {
                    self.shutdownMenuItem?.isEnabled = true
                    self.showShutdownError(error)
                }
            }
        }
    }

    private func showShutdownError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = localizer.shutdownFailedTitle
        alert.informativeText = String(describing: error)
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func makeStatusImage() -> NSImage? {
        guard let symbol = NSImage(
            systemSymbolName: "power.circle",
            accessibilityDescription: "VirtConnector"
        ) else {
            return nil
        }

        let image = NSImage(size: NSSize(width: 28, height: 22))
        image.lockFocus()

        let symbolSize = NSSize(width: 17, height: 17)
        let rect = NSRect(
            x: (image.size.width - symbolSize.width) / 2,
            y: (image.size.height - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        symbol.draw(in: rect)

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func makeShutdownAlertIcon() -> NSImage? {
        NSImage(systemSymbolName: "power.circle.fill", accessibilityDescription: localizer.shutdownDialogTitle)
            ?? NSImage(named: NSImage.cautionName)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        handlePowerOff(reason: "NSApplication.applicationShouldTerminate", shouldExit: false)
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        handlePowerOff(reason: "NSApplication.applicationWillTerminate", shouldExit: false)
    }

    private func execute(_ trigger: PowerTrigger) {
        let config = configStore.loadOrDefault()
        _ = executor.execute(trigger: trigger, config: config)
    }

    private func handlePowerOff(reason: String, shouldExit: Bool) {
        if powerOffHandled {
            log.write("Skipping duplicate power_off trigger from \(reason)")
            return
        }

        powerOffHandled = true
        log.write("Detected \(reason); running power_off actions\(shouldExit ? " before exit" : "")")
        execute(.powerOff)
    }
}

private struct AgentLocalizer {
    private let languageCode: String

    init(preferredLanguages: [String] = Locale.preferredLanguages) {
        languageCode = preferredLanguages.first?.lowercased() ?? "en"
    }

    var shutdownMenuTitle: String {
        isJapanese ? "システム終了..." : "Shut Down..."
    }

    var shutdownDialogTitle: String {
        isJapanese ? "このMacをシステム終了しますか？" : "Shut Down This Mac?"
    }

    var shutdownDialogMessage: String {
        if isJapanese {
            return "VirtConnectorは設定済みの電源オフ動作を実行してから、macOSのシステム終了を要求します。"
        }
        return "VirtConnector will run configured power-off actions before requesting macOS shutdown."
    }

    var shutdownButtonTitle: String {
        isJapanese ? "システム終了" : "Shut Down"
    }

    var cancelButtonTitle: String {
        isJapanese ? "キャンセル" : "Cancel"
    }

    var shutdownFailedTitle: String {
        isJapanese ? "システム終了に失敗しました" : "Shutdown Failed"
    }

    private var isJapanese: Bool {
        languageCode == "ja" || languageCode.hasPrefix("ja-") || languageCode.hasPrefix("ja_")
    }
}
