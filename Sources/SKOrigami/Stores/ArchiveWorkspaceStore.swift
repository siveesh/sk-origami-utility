import AppKit
import Foundation

@MainActor
final class ArchiveWorkspaceStore: ObservableObject {
    @Published var archives: [ArchiveDocument] = []
    @Published var selectedArchiveID: ArchiveDocument.ID?
    @Published var selectedEntryIDs: Set<ArchiveEntry.ID> = []
    @Published var searchText = ""
    @Published var jobMessage = "Drop archives here or open one from the File menu."
    @Published var isWorking = false
    @Published var isShowingCreateSheet = false
    @Published var isShowingExtractSheet = false
    @Published var isShowingPasswordVault = false
    @Published var passwordRecords: [PasswordRecord] = []
    @Published var lastError: String?

    let archiveService = ArchiveService()
    private let passwordVault = PasswordVault()

    var selectedArchive: ArchiveDocument? {
        archives.first { $0.id == selectedArchiveID }
    }

    var filteredEntries: [ArchiveEntry] {
        guard let archive = selectedArchive else { return [] }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return archive.entries
        }
        return archive.entries.filter { $0.path.localizedCaseInsensitiveContains(searchText) }
    }

    init() {
        passwordRecords = passwordVault.load()
        registerDefaultPreferences()
        AppDelegate.openHandler = { [weak self] urls in
            Task { @MainActor in
                self?.openArchives(urls)
            }
        }
        if !AppDelegate.pendingOpenURLs.isEmpty {
            let urls = AppDelegate.pendingOpenURLs
            AppDelegate.pendingOpenURLs.removeAll()
            openArchives(urls)
        }
    }

    func registerDefaultPreferences() {
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.defaultExtractSameLocation: true,
            PreferenceKeys.filterUnnecessaryFiles: true,
            PreferenceKeys.moveArchiveToTrashAfterExtraction: false,
            PreferenceKeys.quitAfterLastWindowCloses: false
        ])
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "Open Archives"
        if panel.runModal() == .OK {
            openArchives(panel.urls)
        }
    }

    func openArchives(_ urls: [URL]) {
        for url in urls {
            let document = ArchiveDocument(url: url, format: ArchiveFormat.infer(from: url), status: .loading)
            archives.insert(document, at: 0)
            selectedArchiveID = document.id
            loadEntries(for: document.id)
        }
    }

    func loadEntries(for archiveID: ArchiveDocument.ID) {
        guard let index = archives.firstIndex(where: { $0.id == archiveID }) else { return }
        let url = archives[index].url
        isWorking = true
        jobMessage = "Reading \(url.lastPathComponent)..."

        Task {
            do {
                let entries = try await archiveService.listEntries(for: url)
                if let index = archives.firstIndex(where: { $0.id == archiveID }) {
                    archives[index].entries = entries
                    archives[index].status = .ready
                    selectedArchiveID = archiveID
                    jobMessage = "Loaded \(entries.count) item\(entries.count == 1 ? "" : "s")."
                }
            } catch {
                if let index = archives.firstIndex(where: { $0.id == archiveID }) {
                    archives[index].status = .failed(error.localizedDescription)
                }
                lastError = error.localizedDescription
                jobMessage = "Could not read archive."
            }
            isWorking = false
        }
    }

    func createArchive(_ request: CreateArchiveRequest) {
        isWorking = true
        jobMessage = "Creating archive..."
        Task {
            do {
                let url = try await archiveService.createArchive(request)
                if !request.password.isEmpty {
                    rememberPassword(for: url, format: request.format, password: request.password)
                }
                openArchives([url])
                jobMessage = "Created \(url.lastPathComponent)."
                isShowingCreateSheet = false
            } catch {
                lastError = error.localizedDescription
                jobMessage = "Could not create archive."
            }
            isWorking = false
        }
    }

    func extractSelectedArchive(destination: URL, password: String, filter: Bool, moveToTrash: Bool) {
        guard let archive = selectedArchive else { return }
        isWorking = true
        jobMessage = "Extracting \(archive.displayName)..."
        let request = ExtractArchiveRequest(
            archive: archive,
            selectedEntries: selectedEntryIDs,
            destination: destination,
            password: password,
            filterUnnecessaryFiles: filter,
            moveArchiveToTrash: moveToTrash
        )

        Task {
            do {
                try await archiveService.extractArchive(request)
                if !password.isEmpty {
                    rememberPassword(for: archive.url, format: archive.format, password: password)
                }
                jobMessage = "Extraction complete."
                isShowingExtractSheet = false
            } catch {
                lastError = error.localizedDescription
                jobMessage = "Could not extract archive."
            }
            isWorking = false
        }
    }

    func addFilesToSelectedArchive(_ files: [URL]) {
        guard let archive = selectedArchive else { return }
        isWorking = true
        jobMessage = "Adding files to \(archive.displayName)..."
        Task {
            do {
                try await archiveService.addFiles(files, to: archive)
                loadEntries(for: archive.id)
                jobMessage = "Archive updated."
            } catch {
                lastError = error.localizedDescription
                jobMessage = "Could not update archive."
                isWorking = false
            }
        }
    }

    func rememberPassword(for url: URL, format: ArchiveFormat, password: String) {
        let record = PasswordRecord(
            archiveName: url.lastPathComponent,
            archivePath: url.path,
            format: format,
            password: password,
            createdAt: Date()
        )
        passwordRecords.removeAll { $0.archivePath == record.archivePath }
        passwordRecords.insert(record, at: 0)
        passwordVault.save(passwordRecords)
    }

    func deletePasswordRecords(at offsets: IndexSet) {
        passwordRecords.remove(atOffsets: offsets)
        passwordVault.save(passwordRecords)
    }
}
