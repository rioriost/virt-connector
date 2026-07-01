import Foundation

public struct DisplayLogEntry: Equatable {
    public var key: String
    public var trigger: PowerTrigger
    public var rawLine: String
}

public struct DisplayLogReader {
    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func latestDisplayEntry() throws -> DisplayLogEntry? {
        let result = try processRunner.run(
            "/bin/sh",
            ["-c", "/usr/bin/pmset -g log | /usr/bin/grep 'Display is turned' | /usr/bin/tail -1"]
        )

        let line = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else {
            return nil
        }

        return parse(line)
    }

    private func parse(_ line: String) -> DisplayLogEntry? {
        let parts = line.split(separator: " ", maxSplits: 3).map(String.init)
        guard parts.count >= 2 else {
            return nil
        }

        let trigger: PowerTrigger
        if line.contains("Display is turned on") {
            trigger = .displayOn
        } else if line.contains("Display is turned off") {
            trigger = .displayOff
        } else {
            return nil
        }

        return DisplayLogEntry(
            key: "\(parts[0]) \(parts[1])",
            trigger: trigger,
            rawLine: line
        )
    }
}
