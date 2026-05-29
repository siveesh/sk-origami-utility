import Foundation

struct ProcessResult {
    var exitCode: Int32
    var standardOutput: String
    var standardError: String
}

enum ProcessRunnerError: LocalizedError {
    case missingExecutable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingExecutable(let name):
            "\(name) is not installed or could not be found."
        case .failed(let message):
            message
        }
    }
}

final class ProcessRunner {
    func locate(_ candidates: [String]) -> String? {
        for candidate in candidates {
            if let bundled = bundledTool(named: candidate) {
                return bundled
            }
            if candidate.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
            for directory in ["/usr/bin", "/bin", "/usr/local/bin", "/opt/homebrew/bin"] {
                let path = "\(directory)/\(candidate)"
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }
        return nil
    }

    private func bundledTool(named name: String) -> String? {
        let platform = "darwin-arm64"
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let bundledURL = resourceURL.appendingPathComponent("Tools/\(platform)/\(name)")
        return FileManager.default.isExecutableFile(atPath: bundledURL.path) ? bundledURL.path : nil
    }

    func run(_ executable: String, arguments: [String], currentDirectory: URL? = nil) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let out = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessResult(exitCode: process.terminationStatus, standardOutput: out, standardError: err))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
