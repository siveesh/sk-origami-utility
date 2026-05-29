import Foundation

struct CreateArchiveRequest {
    var sources: [URL]
    var destinationFolder: URL
    var archiveName: String
    var format: ArchiveFormat
    var password: String
    var splitVolumeSize: String
}

struct ExtractArchiveRequest {
    var archive: ArchiveDocument
    var selectedEntries: Set<ArchiveEntry.ID>
    var destination: URL
    var password: String
    var filterUnnecessaryFiles: Bool
    var moveArchiveToTrash: Bool
}

final class ArchiveService {
    private let runner = ProcessRunner()

    var tools: [ToolAvailability] {
        [
            ToolAvailability(name: "zip", path: runner.locate(["zip"])),
            ToolAvailability(name: "unzip", path: runner.locate(["unzip"])),
            ToolAvailability(name: "zipinfo", path: runner.locate(["zipinfo"])),
            ToolAvailability(name: "ditto", path: runner.locate(["ditto"])),
            ToolAvailability(name: "tar", path: runner.locate(["tar"])),
            ToolAvailability(name: "7zz", path: runner.locate(["7zz"])),
            ToolAvailability(name: "unar", path: runner.locate(["unar"])),
            ToolAvailability(name: "lsar", path: runner.locate(["lsar"])),
            ToolAvailability(name: "tnef", path: runner.locate(["tnef"]))
        ]
    }

    func listEntries(for url: URL) async throws -> [ArchiveEntry] {
        let format = ArchiveFormat.infer(from: url)
        switch format {
        case .zip, .jar, .apk, .drfx:
            return try await listZipEntries(url)
        case .tar, .tarGzip, .tarXz, .tarBzip2:
            return try await listTarEntries(url)
        case .sevenZip, .rar, .rar5:
            return try await listSevenZipStyleEntries(url)
        case .gzip:
            return [ArchiveEntry(path: url.deletingPathExtension().lastPathComponent, sizeDescription: "-", modifiedDescription: "-", isDirectory: false)]
        case .tnef:
            return try await listTNEFEntries(url)
        case .unknown:
            throw ProcessRunnerError.failed("Unsupported or unknown archive format.")
        }
    }

    func createArchive(_ request: CreateArchiveRequest) async throws -> URL {
        let destination = request.destinationFolder
            .appendingPathComponent(request.archiveName)
            .appendingPathExtension(request.format.preferredExtension)

        switch request.format {
        case .zip, .jar, .apk, .drfx:
            try await createZipLikeArchive(request, destination: destination)
        case .tar, .tarGzip, .tarXz, .tarBzip2:
            try await createTarArchive(request, destination: destination)
        case .sevenZip:
            try await createExternalArchive(request, destination: destination)
        default:
            throw ProcessRunnerError.failed("\(request.format.displayName) creation is not available.")
        }

        return destination
    }

    func extractArchive(_ request: ExtractArchiveRequest) async throws {
        try FileManager.default.createDirectory(at: request.destination, withIntermediateDirectories: true)

        switch request.archive.format {
        case .zip, .jar, .apk, .drfx:
            try await extractZipLikeArchive(request)
        case .tar, .tarGzip, .tarXz, .tarBzip2:
            try await extractTarArchive(request)
        case .sevenZip, .rar, .rar5:
            try await extractExternalArchive(request)
        case .gzip:
            try await extractGzip(request)
        case .tnef:
            try await extractTNEF(request)
        case .unknown:
            throw ProcessRunnerError.failed("Unsupported or unknown archive format.")
        }

        if request.filterUnnecessaryFiles {
            removeUnnecessaryFiles(in: request.destination)
        }
        if request.moveArchiveToTrash {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: request.archive.url, resultingItemURL: &trashedURL)
        }
    }

    func addFiles(_ files: [URL], to archive: ArchiveDocument) async throws {
        guard archive.format == .zip || archive.format == .jar || archive.format == .apk || archive.format == .drfx else {
            throw ProcessRunnerError.failed("Modification currently supports ZIP-style archives.")
        }
        guard let zip = runner.locate(["zip"]) else { throw ProcessRunnerError.missingExecutable("zip") }
        let arguments = ["-ur", archive.url.path] + files.map(\.path)
        let result = try await runner.run(zip, arguments: arguments)
        try validate(result)
    }

    private func listZipEntries(_ url: URL) async throws -> [ArchiveEntry] {
        guard let zipinfo = runner.locate(["zipinfo"]) else { throw ProcessRunnerError.missingExecutable("zipinfo") }
        let result = try await runner.run(zipinfo, arguments: ["-1", url.path])
        try validate(result)
        return result.standardOutput.lines.map {
            ArchiveEntry(path: $0, sizeDescription: "-", modifiedDescription: "-", isDirectory: $0.hasSuffix("/"))
        }
    }

    private func listTarEntries(_ url: URL) async throws -> [ArchiveEntry] {
        guard let tar = runner.locate(["tar"]) else { throw ProcessRunnerError.missingExecutable("tar") }
        let result = try await runner.run(tar, arguments: ["-tf", url.path])
        try validate(result)
        return result.standardOutput.lines.map {
            ArchiveEntry(path: $0, sizeDescription: "-", modifiedDescription: "-", isDirectory: $0.hasSuffix("/"))
        }
    }

    private func listSevenZipStyleEntries(_ url: URL) async throws -> [ArchiveEntry] {
        guard let sevenZip = runner.locate(["7zz", "7z", "lsar", "unar", "unrar"]) else {
            throw ProcessRunnerError.missingExecutable("7zz, lsar, unar, or unrar")
        }
        let args = (sevenZip.hasSuffix("lsar") || sevenZip.hasSuffix("unar")) ? ["-l", url.path] : ["l", "-ba", url.path]
        let result = try await runner.run(sevenZip, arguments: args)
        try validate(result)
        return result.standardOutput.lines
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ArchiveEntry(path: $0.trimmingCharacters(in: .whitespaces), sizeDescription: "-", modifiedDescription: "-", isDirectory: false) }
    }

    private func listTNEFEntries(_ url: URL) async throws -> [ArchiveEntry] {
        guard let tnef = runner.locate(["tnef"]) else { throw ProcessRunnerError.missingExecutable("tnef") }
        let result = try await runner.run(tnef, arguments: ["--list", url.path])
        try validate(result)
        return result.standardOutput.lines.map {
            ArchiveEntry(path: $0.trimmingCharacters(in: .whitespaces), sizeDescription: "-", modifiedDescription: "-", isDirectory: false)
        }
    }

    private func createZipLikeArchive(_ request: CreateArchiveRequest, destination: URL) async throws {
        guard let zip = runner.locate(["zip"]) else { throw ProcessRunnerError.missingExecutable("zip") }
        var arguments = ["-r", destination.path] + request.sources.map(\.path)
        if !request.password.isEmpty {
            arguments.insert(contentsOf: ["-P", request.password], at: 0)
        }
        if !request.splitVolumeSize.isEmpty {
            arguments.insert(contentsOf: ["-s", request.splitVolumeSize], at: 0)
        }
        let result = try await runner.run(zip, arguments: arguments)
        try validate(result)
    }

    private func createTarArchive(_ request: CreateArchiveRequest, destination: URL) async throws {
        guard let tar = runner.locate(["tar"]) else { throw ProcessRunnerError.missingExecutable("tar") }
        let flag: String = switch request.format {
        case .tarGzip: "-czf"
        case .tarXz: "-cJf"
        case .tarBzip2: "-cjf"
        default: "-cf"
        }
        let result = try await runner.run(tar, arguments: [flag, destination.path] + request.sources.map(\.path))
        try validate(result)
    }

    private func createExternalArchive(_ request: CreateArchiveRequest, destination: URL) async throws {
        guard let tool = runner.locate(["7zz", "7z"]) else {
            throw ProcessRunnerError.missingExecutable("7z")
        }
        var arguments = ["a", destination.path] + request.sources.map(\.path)
        if !request.password.isEmpty {
            arguments.insert("-p\(request.password)", at: 1)
        }
        if !request.splitVolumeSize.isEmpty {
            arguments.insert("-v\(request.splitVolumeSize)", at: 1)
        }
        let result = try await runner.run(tool, arguments: arguments)
        try validate(result)
    }

    private func extractZipLikeArchive(_ request: ExtractArchiveRequest) async throws {
        guard let unzip = runner.locate(["unzip"]) else { throw ProcessRunnerError.missingExecutable("unzip") }
        var arguments = ["-o", request.archive.url.path, "-d", request.destination.path]
        if !request.password.isEmpty {
            arguments.insert(contentsOf: ["-P", request.password], at: 0)
        }
        if !request.selectedEntries.isEmpty {
            let selectedPaths = request.archive.entries.filter { request.selectedEntries.contains($0.id) }.map(\.path)
            arguments += selectedPaths
        }
        let result = try await runner.run(unzip, arguments: arguments)
        try validate(result)
    }

    private func extractTarArchive(_ request: ExtractArchiveRequest) async throws {
        guard let tar = runner.locate(["tar"]) else { throw ProcessRunnerError.missingExecutable("tar") }
        var arguments = ["-xf", request.archive.url.path, "-C", request.destination.path]
        if !request.selectedEntries.isEmpty {
            arguments += request.archive.entries.filter { request.selectedEntries.contains($0.id) }.map(\.path)
        }
        let result = try await runner.run(tar, arguments: arguments)
        try validate(result)
    }

    private func extractExternalArchive(_ request: ExtractArchiveRequest) async throws {
        guard let tool = runner.locate(["7zz", "7z", "unar", "unrar"]) else {
            throw ProcessRunnerError.missingExecutable("7z, unar, or unrar")
        }
        let arguments: [String]
        if tool.hasSuffix("unar") {
            arguments = ["-o", request.destination.path, request.archive.url.path]
        } else if tool.hasSuffix("unrar") {
            arguments = ["x", "-o+", request.archive.url.path, request.destination.path]
        } else {
            arguments = ["x", "-y", "-o\(request.destination.path)", request.archive.url.path]
        }
        let result = try await runner.run(tool, arguments: arguments)
        try validate(result)
    }

    private func extractGzip(_ request: ExtractArchiveRequest) async throws {
        guard let gunzip = runner.locate(["gunzip"]) else { throw ProcessRunnerError.missingExecutable("gunzip") }
        let result = try await runner.run(gunzip, arguments: ["-k", request.archive.url.path], currentDirectory: request.destination)
        try validate(result)
    }

    private func extractTNEF(_ request: ExtractArchiveRequest) async throws {
        guard let tnef = runner.locate(["tnef"]) else { throw ProcessRunnerError.missingExecutable("tnef") }
        let result = try await runner.run(tnef, arguments: ["--directory", request.destination.path, request.archive.url.path])
        try validate(result)
    }

    private func validate(_ result: ProcessResult) throws {
        guard result.exitCode == 0 else {
            let message = result.standardError.isEmpty ? result.standardOutput : result.standardError
            throw ProcessRunnerError.failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func removeUnnecessaryFiles(in folder: URL) {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator {
            if url.lastPathComponent == ".DS_Store" || url.lastPathComponent == "__MACOSX" {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
