import Foundation

final class ExtractionJob: Identifiable, ObservableObject {
    enum State: Equatable {
        case queued
        case checkingEncryption
        case waitingForPassword
        case extracting
        case done
        case failed(String)

        var label: String {
            switch self {
            case .queued: "Queued"
            case .checkingEncryption: "Checking encryption..."
            case .waitingForPassword: "Waiting for password"
            case .extracting: "Extracting..."
            case .done: "Complete"
            case .failed(let message): "Failed: \(message)"
            }
        }
    }

    let id = UUID()
    let archive: ArchiveDocument
    @Published var state: State = .queued

    init(archive: ArchiveDocument) {
        self.archive = archive
    }
}
