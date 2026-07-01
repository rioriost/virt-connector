import Foundation

public struct ProcessResult {
    public var terminationStatus: Int32
    public var standardOutput: String
    public var standardError: String
}

public enum ProcessRunnerError: LocalizedError {
    case nonZeroExit(executable: String, arguments: [String], status: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case let .nonZeroExit(executable, arguments, status, stderr):
            let command = ([executable] + arguments).joined(separator: " ")
            return "`\(command)` exited with status \(status): \(stderr)"
        }
    }
}

public struct ProcessRunner {
    public init() {}

    @discardableResult
    public func run(
        _ executable: String,
        _ arguments: [String] = [],
        allowNonZeroExit: Bool = false
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && !allowNonZeroExit {
            throw ProcessRunnerError.nonZeroExit(
                executable: executable,
                arguments: arguments,
                status: process.terminationStatus,
                stderr: error.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return ProcessResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output,
            standardError: error
        )
    }
}
