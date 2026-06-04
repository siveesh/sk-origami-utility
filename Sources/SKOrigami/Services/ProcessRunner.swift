import Foundation

struct ProcessResult {
    var exitCode: Int32
    var standardOutput: String
    var standardError: String
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var outputData = Data()
    private var errorData = Data()

    func storeOutput(_ data: Data) {
        lock.lock()
        outputData = data
        lock.unlock()
    }

    func storeError(_ data: Data) {
        lock.lock()
        errorData = data
        lock.unlock()
    }

    func result(exitCode: Int32) -> ProcessResult {
        lock.lock()
        defer { lock.unlock() }
        return ProcessResult(
            exitCode: exitCode,
            standardOutput: String(data: outputData, encoding: .utf8) ?? "",
            standardError: String(data: errorData, encoding: .utf8) ?? ""
        )
    }
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
        let standardError = Pipe()
        process.standardOutput = output
        process.standardError = standardError

        return try await withCheckedThrowingContinuation { continuation in
            let group = DispatchGroup()
            let buffer = ProcessOutputBuffer()

            process.terminationHandler = { process in
                group.notify(queue: .global()) {
                    continuation.resume(returning: buffer.result(exitCode: process.terminationStatus))
                }
            }

            group.enter()
            DispatchQueue.global().async {
                buffer.storeOutput(output.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                buffer.storeError(standardError.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }

            do {
                try process.run()
                output.fileHandleForWriting.closeFile()
                standardError.fileHandleForWriting.closeFile()
            } catch {
                output.fileHandleForWriting.closeFile()
                standardError.fileHandleForWriting.closeFile()
                continuation.resume(throwing: error)
            }
        }
    }
}
