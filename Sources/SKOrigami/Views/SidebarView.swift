import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    var body: some View {
        List(selection: $workspace.selectedArchiveID) {
            Section("Archives") {
                if workspace.archives.isEmpty {
                    ContentUnavailableView("No Archives", systemImage: "archivebox")
                } else {
                    ForEach(workspace.archives) { archive in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(archive.displayName)
                                .lineLimit(1)
                            Text("\(archive.format.displayName) - \(archive.status.message)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .tag(archive.id)
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([archive.url])
                            }
                            Button("Reload") {
                                workspace.loadEntries(for: archive.id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}
