import Foundation

public final class ConfigStore {
    public let configURL: URL

    public init(configURL: URL = ConfigStore.defaultConfigURL()) {
        self.configURL = configURL
    }

    public static func defaultConfigURL() -> URL {
        if let path = ProcessInfo.processInfo.environment["VIRT_CONNECTOR_CONFIG"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("virt-connector", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public static func logsDirectoryURL() -> URL {
        if let path = ProcessInfo.processInfo.environment["VIRT_CONNECTOR_LOG_DIR"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }

    public static func launchAgentsDirectoryURL() -> URL {
        if let path = ProcessInfo.processInfo.environment["VIRT_CONNECTOR_LAUNCH_AGENTS_DIR"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
    }

    public func load() throws -> VirtConnectorConfig {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(VirtConnectorConfig.self, from: data)
    }

    public func loadOrDefault() -> VirtConnectorConfig {
        (try? load()) ?? VirtConnectorConfig()
    }

    public func save(_ config: VirtConnectorConfig) throws {
        let directory = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: [.atomic])
    }

    public func ensureDefaultConfig() throws -> VirtConnectorConfig {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return try load()
        }

        let config = VirtConnectorConfig(devices: [VirtConnectorConfig.sampleDevice])
        try save(config)
        return config
    }
}
