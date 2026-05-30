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
    @Published var diskImageJobs: [DiskImageJob] = []
    @Published var passwordRecords: [PasswordRecord] = []
    @Published var lastError: String?
    @Published var dropBehavior: DropBehavior = .createDiskImage
    @Published var pendingCreateSources: [URL] = []

    let archiveService = ArchiveService()
    let diskImageService = DiskImageService()
    private let passwordVault = PasswordVault()
    private var isCreatingDiskImage = false

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
                self?.handleIncomingURLs(urls)
            }
        }
        if !AppDelegate.pendingOpenURLs.isEmpty {
            let urls = AppDelegate.pendingOpenURLs
            AppDelegate.pendingOpenURLs.removeAll()
            handleIncomingURLs(urls)
        }
    }

    func registerDefaultPreferences() {
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.defaultExtractSameLocation: true,
            PreferenceKeys.filterUnnecessaryFiles: true,
            PreferenceKeys.moveArchiveToTrashAfterExtraction: false,
            PreferenceKeys.moveFolderToTrashAfterDiskImageCreation: false,
            PreferenceKeys.quitAfterLastWindowCloses: false
        ])
    }

    func presentOpenPanel() {
        setDropBehavior(.openArchives)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "Open Archives"
        if panel.runModal() == .OK {
            openArchives(panel.urls)
        }
    }

    func setDropBehavior(_ behavior: DropBehavior) {
        dropBehavior = behavior
        jobMessage = behavior.statusMessage
    }

    func openArchives(_ urls: [URL]) {
        for url in urls {
            let document = ArchiveDocument(url: url, format: ArchiveFormat.infer(from: url), status: .loading)
            archives.insert(document, at: 0)
            selectedArchiveID = document.id
            loadEntries(for: document.id)
        }
    }

    func handleIncomingURLs(_ urls: [URL]) {
        let folders = urls.filter(\.isExistingDirectory)
        let files = urls.filter { !$0.isExistingDirectory }

        switch dropBehavior {
        case .openArchives:
            if !files.isEmpty {
                openArchives(files)
            }
            if !folders.isEmpty {
                lastError = "Open mode accepts archive files. Switch to Disk Image or Create mode for folders."
            }
        case .createArchive:
            presentCreateArchive(sources: urls)
        case .createDiskImage:
            guard !folders.isEmpty else {
                lastError = "Disk Image mode accepts folders. Switch to Open or Create mode for files."
                return
            }
            stageDiskImageFolders(folders)
            if !files.isEmpty {
                lastError = "Disk Image mode ignored file drops. Switch to Create mode to archive files."
            }
        case .extractArchive:
            guard let archiveURL = files.first else {
                lastError = "Extract mode accepts archive files."
                return
            }
            openArchives([archiveURL])
            isShowingExtractSheet = true
        }
    }

    func presentCreateArchive(sources: [URL] = []) {
        setDropBehavior(.createArchive)
        pendingCreateSources = sources
        isShowingCreateSheet = true
    }

    func consumePendingCreateSources() -> [URL] {
        let sources = pendingCreateSources
        pendingCreateSources = []
        return sources
    }

    func presentFolderImagePanel() {
        setDropBehavior(.createDiskImage)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.title = "Choose Folders"
        panel.prompt = "Add"
        if panel.runModal() == .OK {
            stageDiskImageFolders(panel.urls)
        }
    }

    func stageDiskImageFolders(_ urls: [URL]) {
        for url in urls where url.isExistingDirectory {
            let job = DiskImageJob(
                sourceURL: url,
                outputName: DiskImageService.sanitize(url.lastPathComponent),
                format: .dmg
            )
            diskImageJobs.insert(job, at: 0)
            selectedArchiveID = nil
            jobMessage = "Folder staged for disk image creation."

            Task {
                let detected = await Task.detached(priority: .utility) {
                    DiskImageService.detectFormat(for: url)
                }.value
                job.format = detected
                job.windowsContent = detected == .iso
                job.note = detected == .iso ? "Windows content detected" : ""
            }
        }
    }

    func removeDiskImageJob(_ job: DiskImageJob) {
        diskImageJobs.removeAll { $0.id == job.id && $0.state == .staged }
    }

    func setAllStagedDiskImageJobs(to format: DiskImageFormat) {
        diskImageJobs
            .filter { $0.state == .staged }
            .forEach { job in
                job.format = format
                job.note = format == .iso && job.windowsContent ? "Windows content detected" : ""
            }
    }

    func startDiskImageJobs() {
        let staged = diskImageJobs.filter { $0.state == .staged }
        guard !staged.isEmpty else { return }

        staged.forEach {
            $0.outputName = DiskImageService.sanitize($0.outputName)
            $0.state = .queued
            $0.note = ""
        }
        processNextDiskImageJob()
    }

    func clearFinishedDiskImageJobs() {
        diskImageJobs.removeAll { job in
            switch job.state {
            case .done, .failed:
                true
            default:
                false
            }
        }
    }

    private func processNextDiskImageJob() {
        guard !isCreatingDiskImage, let job = diskImageJobs.first(where: { $0.state == .queued }) else { return }
        isCreatingDiskImage = true
        isWorking = true
        job.state = .creating
        jobMessage = "Creating \(job.outputFileName)..."

        Task {
            do {
                let url = try await diskImageService.createDiskImage(CreateDiskImageRequest(
                    sourceFolder: job.sourceURL,
                    outputName: job.outputName,
                    format: job.format,
                    moveSourceFolderToTrash: UserDefaults.standard.bool(forKey: PreferenceKeys.moveFolderToTrashAfterDiskImageCreation)
                ))
                job.outputURL = url
                job.state = .done
                job.note = ""
                jobMessage = "Created \(url.lastPathComponent)."
            } catch {
                job.state = .failed(error.localizedDescription)
                job.note = error.localizedDescription
                lastError = error.localizedDescription
                jobMessage = "Could not create disk image."
            }
            isCreatingDiskImage = false
            isWorking = diskImageJobs.contains { $0.state == .queued || $0.state == .creating }
            processNextDiskImageJob()
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
