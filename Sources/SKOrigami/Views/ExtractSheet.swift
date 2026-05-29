import SwiftUI

struct ExtractSheet: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKeys.defaultExtractSameLocation) private var sameLocation = true
    @AppStorage(PreferenceKeys.filterUnnecessaryFiles) private var filterUnnecessaryFiles = true
    @AppStorage(PreferenceKeys.moveArchiveToTrashAfterExtraction) private var moveArchiveToTrash = false

    @State private var customDestination = FileManager.default.homeDirectoryForCurrentUser
    @State private var password = ""

    private var destination: URL {
        if sameLocation, let archive = workspace.selectedArchive {
            return archive.containingFolder
        }
        return customDestination
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Extract Archive")
                .font(.title2)
                .fontWeight(.semibold)

            if let archive = workspace.selectedArchive {
                LabeledContent("Archive", value: archive.displayName)
                LabeledContent("Format", value: archive.format.displayName)
                LabeledContent("Selected", value: workspace.selectedEntryIDs.isEmpty ? "All items" : "\(workspace.selectedEntryIDs.count) item\(workspace.selectedEntryIDs.count == 1 ? "" : "s")")
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Toggle("Same Location as Archive", isOn: $sameLocation)

            HStack {
                Text(destination.path)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Choose") {
                    chooseDestination()
                }
                .disabled(sameLocation)
            }

            Toggle("Filter .DS_Store and __MACOSX", isOn: $filterUnnecessaryFiles)
            Toggle("Move Archive to Trash", isOn: $moveArchiveToTrash)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Extract") {
                    workspace.extractSelectedArchive(
                        destination: destination,
                        password: password,
                        filter: filterUnnecessaryFiles,
                        moveToTrash: moveArchiveToTrash
                    )
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            customDestination = url
        }
    }
}
