import Foundation

struct CreateDiskImageRequest {
    var sourceFolder: URL
    var outputName: String
    var format: DiskImageFormat
    var moveSourceFolderToTrash: Bool
}

final class DiskImageService {
    private let runner = ProcessRunner()

    var toolAvailability: ToolAvailability {
        ToolAvailability(name: "hdiutil", path: runner.locate(["/usr/bin/hdiutil", "hdiutil"]))
    }

    func createDiskImage(_ request: CreateDiskImageRequest) async throws -> URL {
        guard let hdiutil = runner.locate(["/usr/bin/hdiutil", "hdiutil"]) else {
            throw ProcessRunnerError.missingExecutable("hdiutil")
        }

        let source = request.sourceFolder
        let parent = source.deletingLastPathComponent()
        let cleanName = Self.sanitize(request.outputName)

        let outputURL: URL
        let arguments: [String]
        switch request.format {
        case .dmg:
            outputURL = parent.appendingPathComponent(cleanName).appendingPathExtension("dmg")
            try? FileManager.default.removeItem(at: outputURL)
            arguments = [
                "create",
                "-volname", source.lastPathComponent,
                "-srcfolder", source.path,
                "-ov",
                "-format", "UDZO",
                outputURL.path
            ]
        case .iso:
            let outputBase = parent.appendingPathComponent(cleanName)
            outputURL = outputBase.appendingPathExtension("iso")
            try? FileManager.default.removeItem(at: outputURL)
            arguments = [
                "makehybrid",
                "-iso",
                "-joliet",
                "-o", outputBase.path,
                source.path
            ]
        }

        try await runHdiutil(hdiutil, arguments: arguments)

        if request.moveSourceFolderToTrash {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: source, resultingItemURL: &trashedURL)
        }

        return outputURL
    }

    private func runHdiutil(_ executable: String, arguments: [String]) async throws {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice

            let errorPipe = Pipe()
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                throw error
            }

            guard process.terminationStatus == 0 else {
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                throw ProcessRunnerError.failed(
                    message.isEmpty ? "hdiutil exited with code \(process.terminationStatus)" : message
                )
            }
        }.value
    }

    static func detectFormat(for url: URL) -> DiskImageFormat {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return .dmg }

        for case let file as URL in enumerator {
            let ext = file.pathExtension.lowercased()
            if ext == "exe" || ext == "msi" {
                return .iso
            }
        }
        return .dmg
    }

    static func sanitize(_ raw: String) -> String {
        var value = raw

        for knownExt in ["dmg", "iso", "img"] where value.lowercased().hasSuffix(".\(knownExt)") {
            value = String(value.dropLast(knownExt.count + 1))
        }

        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|\0\r\n")
        value = value.unicodeScalars
            .filter { !forbidden.contains($0) }
            .reduce("") { $0 + String($1) }

        value = value.components(separatedBy: "..").joined(separator: "_")
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasPrefix(".") {
            value = String(value.dropFirst())
        }

        return value.isEmpty ? "output" : String(value.prefix(200))
    }
}
