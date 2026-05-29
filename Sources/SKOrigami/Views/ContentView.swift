import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

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
                }

                Button {
                    workspace.isShowingCreateSheet = true
                } label: {
                    Label("Create", systemImage: "archivebox")
                }

                Button {
                    workspace.isShowingExtractSheet = true
                } label: {
                    Label("Extract", systemImage: "square.and.arrow.down")
                }
                .disabled(workspace.selectedArchive == nil)

                Button {
                    workspace.isShowingPasswordVault = true
                } label: {
                    Label("Passwords", systemImage: "key")
                }
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadDroppedFiles(providers)
        }
    }

    private func loadDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard
                    let data,
                    let string = String(data: data, encoding: .utf8),
                    let url = URL(string: string)
                else { return }
                Task { @MainActor in
                    workspace.openArchives([url])
                }
            }
        }
        return true
    }
}
