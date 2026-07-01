import Foundation

public struct ActionExecutionResult {
    public var attempted: Int
    public var failed: Int
}

public struct ActionExecutor {
    private let shortcutRunner: ShortcutRunner
    private let log: FileLog?

    public init(shortcutRunner: ShortcutRunner = ShortcutRunner(), log: FileLog? = nil) {
        self.shortcutRunner = shortcutRunner
        self.log = log
    }

    @discardableResult
    public func execute(trigger: PowerTrigger, config: VirtConnectorConfig) -> ActionExecutionResult {
        guard config.enabled else {
            log?.write("Skipping \(trigger.rawValue): monitoring is disabled")
            return ActionExecutionResult(attempted: 0, failed: 0)
        }

        var attempted = 0
        var failed = 0

        for device in config.devices where device.enabled {
            let action = device.actions.action(for: trigger)
            guard let shortcutName = device.shortcutName(for: action) else {
                log?.write("Skipping \(device.name) for \(trigger.rawValue): action is none")
                continue
            }

            attempted += 1
            log?.write("Running shortcut '\(shortcutName)' for \(device.name) on \(trigger.rawValue)")

            do {
                try shortcutRunner.runShortcut(named: shortcutName)
            } catch {
                failed += 1
                log?.write("Shortcut '\(shortcutName)' failed for \(device.name): \(error)")
            }
        }

        log?.write("Completed \(trigger.rawValue): attempted=\(attempted) failed=\(failed)")
        return ActionExecutionResult(attempted: attempted, failed: failed)
    }
}
