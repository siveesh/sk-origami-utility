import Foundation

struct ArchiveDocument: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let format: ArchiveFormat
    var entries: [ArchiveEntry] = []
    var status: ArchiveStatus = .pending

    var displayName: String { url.lastPathComponent }
    var containingFolder: URL { url.deletingLastPathComponent() }
}

struct ArchiveEntry: Identifiable, Hashable {
    let id = UUID()
    var path: String
    var sizeDescription: String
    var modifiedDescription: String
    var isDirectory: Bool

    var displayName: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

enum ArchiveStatus: Equatable {
    case pending
    case loading
    case ready
    case failed(String)

    var message: String {
        switch self {
        case .pending: "Ready"
        case .loading: "Reading archive..."
        case .ready: "Contents loaded"
        case .failed(let message): message
        }
    }
}

struct PasswordRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var archiveName: String
    var archivePath: String
    var format: ArchiveFormat
    var password: String
    var createdAt: Date
}

struct ToolAvailability: Hashable {
    var name: String
    var path: String?

    var isAvailable: Bool { path != nil }

    var displayLocation: String {
        guard let path else { return "Not installed" }
        if path.contains(".app/Contents/Resources/Tools/") {
            return "Bundled in app"
        }
        return path
    }
}
