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
            if isMultipartArchive(url) {
                return try await listSevenZipStyleEntries(url)
            }
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
            if isMultipartArchive(request.archive.url) {
                try await extractExternalArchive(request)
            } else {
                try await extractZipLikeArchive(request)
            }
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
            try trashArchiveFamily(containing: request.archive.url)
        }
    }

    func isEncrypted(_ url: URL) async throws -> Bool {
        let format = ArchiveFormat.infer(from: url)
        switch format {
        case .zip, .jar, .apk, .drfx:
            guard let zipinfo = runner.locate(["zipinfo"]) else { throw ProcessRunnerError.missingExecutable("zipinfo") }
            let result = try await runner.run(zipinfo, arguments: ["-v", url.path])
            try validate(result)
            return result.standardOutput.lines
                .map { $0.lowercased() }
                .contains { $0.contains("file security status:") && $0.contains("encrypted") && !$0.contains("not encrypted") }
        case .sevenZip, .rar, .rar5:
            guard let sevenZip = runner.locate(["7zz", "7z"]) else {
                throw ProcessRunnerError.missingExecutable("7z")
            }
            let result = try await runner.run(sevenZip, arguments: ["l", "-slt", url.path])
            try validate(result)
            return result.standardOutput.contains("Encrypted = +")
        default:
            return false
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
        if let splitVolumeSize = normalizedSplitVolumeSize(from: request.splitVolumeSize) {
            arguments.insert(contentsOf: ["-s", splitVolumeSize], at: 0)
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
        if let splitVolumeSize = normalizedSplitVolumeSize(from: request.splitVolumeSize) {
            arguments.insert("-v\(splitVolumeSize)", at: 1)
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
        if request.archive.format == .rar || request.archive.format == .rar5,
           let unar = runner.locate(["unar"]) {
            try validate(try await extractWithUnar(request, tool: unar))
            return
        }

        guard let tool = runner.locate(["7zz", "7z", "unar", "unrar"]) else {
            throw ProcessRunnerError.missingExecutable("7z, unar, or unrar")
        }
        let result: ProcessResult
        if tool.hasSuffix("unar") {
            result = try await extractWithUnar(request, tool: tool)
        } else if tool.hasSuffix("unrar") {
            let arguments = ["x", "-o+"] + (request.password.isEmpty ? [] : ["-p\(request.password)"]) + [request.archive.url.path, request.destination.path]
            result = try await runner.run(tool, arguments: arguments)
        } else {
            let arguments = ["x", "-y"] + (request.password.isEmpty ? [] : ["-p\(request.password)"]) + ["-o\(request.destination.path)", request.archive.url.path]
            let sevenZipResult = try await runner.run(tool, arguments: arguments)
            if sevenZipResult.exitCode != 0,
               request.archive.format == .rar || request.archive.format == .rar5,
               let unar = runner.locate(["unar"]) {
                result = try await extractWithUnar(request, tool: unar)
            } else {
                result = sevenZipResult
            }
        }
        try validate(result)
    }

    private func extractWithUnar(_ request: ExtractArchiveRequest, tool: String) async throws -> ProcessResult {
        var arguments = ["-q", "-f", "-nr", "-o", request.destination.path]
        if !request.password.isEmpty {
            arguments += ["-p", request.password]
        }
        arguments.append(request.archive.url.path)
        return try await runner.run(tool, arguments: arguments)
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

    private func normalizedSplitVolumeSize(from rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return nil }
        return value
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "mb", with: "m")
            .replacingOccurrences(of: "gb", with: "g")
            .replacingOccurrences(of: "kb", with: "k")
    }

    private func isMultipartArchive(_ url: URL) -> Bool {
        archiveFamilyURLs(containing: url).count > 1 || isMultipartSegmentName(url.lastPathComponent.lowercased())
    }

    func archiveFamilyURLs(containing url: URL) -> [URL] {
        let folder = url.deletingLastPathComponent()
        guard let siblings = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [url]
        }

        let names = Set(multipartFamilyNames(for: url.lastPathComponent.lowercased()))
        guard !names.isEmpty else { return [url] }

        let family = siblings
            .filter { names.contains($0.lastPathComponent.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return family.isEmpty ? [url] : family
    }

    func primaryArchiveURL(containing url: URL) -> URL {
        let family = archiveFamilyURLs(containing: url)
        let namesByLowercase = Dictionary(uniqueKeysWithValues: family.map { ($0.lastPathComponent.lowercased(), $0) })
        let selectedName = url.lastPathComponent.lowercased()

        if selectedName.range(of: #"\.z\d{2,3}$"#, options: .regularExpression) != nil ||
            selectedName.hasSuffix(".zip") {
            let prefix = removingPathExtension(from: selectedName)
            if let finalZip = namesByLowercase["\(prefix).zip"] {
                return finalZip
            }
        }

        if selectedName.range(of: #"\.r\d{2,3}$"#, options: .regularExpression) != nil ||
            selectedName.hasSuffix(".rar") {
            let prefix = removingPathExtension(from: selectedName)
            if let rar = namesByLowercase["\(prefix).rar"] {
                return rar
            }
        }

        return family.first ?? url
    }

    private func trashArchiveFamily(containing url: URL) throws {
        for part in archiveFamilyURLs(containing: url) where FileManager.default.fileExists(atPath: part.path) {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: part, resultingItemURL: &trashedURL)
        }
    }

    private func multipartFamilyNames(for fileName: String) -> [String] {
        let name = fileName.lowercased()
        let archiveExtensions = ["7z", "zip"]

        for archiveExtension in archiveExtensions {
            let marker = ".\(archiveExtension)."
            if let range = name.range(of: marker, options: .backwards) {
                let prefix = String(name[..<range.upperBound])
                return numberedFamilyNames(prefix: prefix, digits: 3)
            }
        }

        if name.range(of: #"\.z\d{2,3}$"#, options: .regularExpression) != nil {
            let prefix = removingPathExtension(from: name)
            return [prefix + ".zip"] + (1...999).map { "\(prefix).z\(String(format: "%02d", $0))" }
        }

        if name.hasSuffix(".zip") {
            let prefix = String(name.dropLast(4))
            return [name] + (1...999).map { "\(prefix).z\(String(format: "%02d", $0))" }
        }

        if let range = name.range(of: #"\.part\d+\.rar$"#, options: .regularExpression) {
            let prefix = String(name[..<range.lowerBound])
            return (1...999).flatMap { number in
                [
                    "\(prefix).part\(number).rar",
                    "\(prefix).part\(String(format: "%02d", number)).rar",
                    "\(prefix).part\(String(format: "%03d", number)).rar"
                ]
            }
        }

        if name.hasSuffix(".rar") {
            let prefix = String(name.dropLast(4))
            return [name] + (0...999).flatMap { number in
                [
                    "\(prefix).r\(String(format: "%02d", number))",
                    "\(prefix).r\(String(format: "%03d", number))"
                ]
            }
        }

        if name.range(of: #"\.r\d{2,3}$"#, options: .regularExpression) != nil {
            let prefix = removingPathExtension(from: name)
            return ["\(prefix).rar"] + (0...999).flatMap { number in
                [
                    "\(prefix).r\(String(format: "%02d", number))",
                    "\(prefix).r\(String(format: "%03d", number))"
                ]
            }
        }

        return [name]
    }

    private func removingPathExtension(from fileName: String) -> String {
        let pathExtension = (fileName as NSString).pathExtension
        guard !pathExtension.isEmpty else { return fileName }
        return String(fileName.dropLast(pathExtension.count + 1))
    }

    private func numberedFamilyNames(prefix: String, digits: Int) -> [String] {
        (1...999).map { "\(prefix)\(String(format: "%0\(digits)d", $0))" }
    }

    private func isMultipartSegmentName(_ name: String) -> Bool {
        name.range(of: #"\.(7z|zip)\.\d{3}$"#, options: .regularExpression) != nil ||
            name.range(of: #"\.z\d{2,3}$"#, options: .regularExpression) != nil ||
            name.range(of: #"\.part\d+\.rar$"#, options: .regularExpression) != nil ||
            name.range(of: #"\.r\d{2,3}$"#, options: .regularExpression) != nil
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
