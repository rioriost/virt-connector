import Foundation

public final class FileLog {
    private let url: URL
    private let formatter: ISO8601DateFormatter

    public init(url: URL) {
        self.url = url
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public static func daemonLog() -> FileLog {
        FileLog(url: ConfigStore.logsDirectoryURL().appendingPathComponent("virt-connectord.log"))
    }

    public func write(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        fputs(line, stdout)

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try Data(line.utf8).write(to: url, options: [.atomic])
            }
        } catch {
            fputs("failed to write log: \(error)\n", stderr)
        }
    }
}
