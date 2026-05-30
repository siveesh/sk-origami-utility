import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            ArchiveDetailView()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    workspace.presentOpenPanel()
                } label: {
                    Label("Open", systemImage: "folder")
                        .foregroundStyle(workspace.dropBehavior == .openArchives ? Color.accentColor : Color.primary)
                }
                .help("Open archives. Drops open archive files.")

                Button {
                    workspace.presentCreateArchive()
                } label: {
                    Label("Create", systemImage: "archivebox")
                        .foregroundStyle(workspace.dropBehavior == .createArchive ? Color.accentColor : Color.primary)
                }
                .help("Create an archive. Drops add files or folders to a new archive.")

                Button {
                    workspace.presentFolderImagePanel()
                } label: {
                    Label("Image", systemImage: "opticaldiscdrive")
                        .foregroundStyle(workspace.dropBehavior == .createDiskImage ? Color.accentColor : Color.primary)
                }
                .help("Create a DMG or ISO. Drops stage folders for disk image creation.")

                Button {
                    workspace.setDropBehavior(.extractArchive)
                    if workspace.selectedArchive != nil {
                        workspace.isShowingExtractSheet = true
                    }
                } label: {
                    Label("Extract", systemImage: "square.and.arrow.down")
                        .foregroundStyle(workspace.dropBehavior == .extractArchive ? Color.accentColor : Color.primary)
                }
                .help("Extract an archive. Drops open an archive and show extraction options.")

                Button {
                    workspace.isShowingPasswordVault = true
                } label: {
                    Label("Passwords", systemImage: "key")
                }
                .help("Open saved archive passwords.")
            }
        }
        .sheet(isPresented: $workspace.isShowingCreateSheet) {
            CreateArchiveSheet()
                .environmentObject(workspace)
        }
        .sheet(isPresented: $workspace.isShowingExtractSheet) {
            ExtractSheet()
                .environmentObject(workspace)
        }
        .sheet(isPresented: $workspace.isShowingPasswordVault) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Passwords")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding([.top, .horizontal])
                PasswordVaultView()
                    .environmentObject(workspace)
            }
            .frame(width: 520, height: 420)
        }
        .alert("Archive Error", isPresented: Binding(
            get: { workspace.lastError != nil },
            set: { if !$0 { workspace.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workspace.lastError ?? "")
        }
        .overlay {
            DropTargetView(
                onFileURLsDropped: { urls in
                    workspace.handleIncomingURLs(urls)
                },
                onIsTargetedChanged: { isDropTargeted = $0 }
            )
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(10)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}
