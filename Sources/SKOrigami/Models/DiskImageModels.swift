import Foundation

enum DiskImageFormat: String, CaseIterable, Identifiable {
    case dmg = "DMG"
    case iso = "ISO"

    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
}

enum DiskImageJobState: Equatable {
    case staged
    case queued
    case creating
    case done
    case failed(String)

    var message: String {
        switch self {
        case .staged: "Ready"
        case .queued: "Queued"
        case .creating: "Creating disk image..."
        case .done: "Created"
        case .failed(let message): message
        }
    }
}

@MainActor
final class DiskImageJob: Identifiable, ObservableObject {
    let id = UUID()
    let sourceURL: URL

    @Published var outputName: String
    @Published var format: DiskImageFormat
    @Published var state: DiskImageJobState = .staged
    @Published var note: String = "Scanning..."
    @Published var windowsContent = false
    @Published var outputURL: URL?

    var sourceFolderName: String { sourceURL.lastPathComponent }
    var outputFileName: String { "\(outputName).\(format.fileExtension)" }

    init(sourceURL: URL, outputName: String, format: DiskImageFormat) {
        self.sourceURL = sourceURL
        self.outputName = outputName
        self.format = format
    }
}

