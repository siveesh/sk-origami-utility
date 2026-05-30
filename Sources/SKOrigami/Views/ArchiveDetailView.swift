import SwiftUI

struct ArchiveDetailView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            if let archive = workspace.selectedArchive {
                header(for: archive)
                Divider()
                ArchiveEntryListView()
                    .environmentObject(workspace)
                Divider()
                StatusBar()
                    .environmentObject(workspace)
            } else {
                VStack(spacing: 0) {
                    DropLandingView()
                        .environmentObject(workspace)
                    if !workspace.diskImageJobs.isEmpty {
                        Divider()
                        DiskImageQueueView()
                            .environmentObject(workspace)
                    }
                }
            }
        }
        .searchable(text: $workspace.searchText, placement: .toolbar, prompt: "Search archive")
    }

    private func header(for archive: ArchiveDocument) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(archive.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(archive.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                workspace.setDropBehavior(.extractArchive)
                workspace.isShowingExtractSheet = true
            } label: {
                Label("Extract", systemImage: "square.and.arrow.down")
            }
            .help("Extract this archive. Drops open an archive and show extraction options.")
            Button {
                chooseFilesToAdd()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .disabled(!(archive.format == .zip || archive.format == .jar || archive.format == .apk || archive.format == .drfx))
        }
        .padding()
    }

    private func chooseFilesToAdd() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK {
            workspace.addFilesToSelectedArchive(panel.urls)
        }
    }
}

struct ArchiveEntryListView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    var body: some View {
        List(workspace.filteredEntries, selection: $workspace.selectedEntryIDs) { entry in
            HStack {
                Image(systemName: entry.isDirectory ? "folder" : "doc")
                    .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                    .frame(width: 24)
                Text(entry.path)
                    .lineLimit(1)
                Spacer()
                Text(entry.sizeDescription)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .tag(entry.id)
        }
        .overlay {
            if workspace.filteredEntries.isEmpty {
                ContentUnavailableView("No Items", systemImage: "doc.text.magnifyingglass")
            }
        }
    }
}

struct DropLandingView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(dropTitle)
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text(workspace.dropBehavior.statusMessage)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    workspace.presentOpenPanel()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .help("Open archives. Drops open archive files.")
                Button {
                    workspace.presentCreateArchive()
                } label: {
                    Label("Create", systemImage: "archivebox")
                }
                .help("Create an archive. Drops add files or folders to a new archive.")
                Button {
                    workspace.presentFolderImagePanel()
                } label: {
                    Label("Add Folders", systemImage: "opticaldiscdrive")
                }
                .help("Create a DMG or ISO. Drops stage folders for disk image creation.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropTitle: String {
        switch workspace.dropBehavior {
        case .openArchives:
            "Drop Archives"
        case .createArchive:
            "Drop to Archive"
        case .createDiskImage:
            "Drop Folders"
        case .extractArchive:
            "Drop to Extract"
        }
    }
}

struct StatusBar: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    var body: some View {
        HStack {
            if workspace.isWorking {
                ProgressView()
                    .controlSize(.small)
            }
            Text(workspace.jobMessage)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("\(workspace.filteredEntries.count) item\(workspace.filteredEntries.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
