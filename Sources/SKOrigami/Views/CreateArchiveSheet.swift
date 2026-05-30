import SwiftUI

struct CreateArchiveSheet: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore
    @Environment(\.dismiss) private var dismiss

    @State private var sources: [URL] = []
    @State private var destinationFolder = FileManager.default.homeDirectoryForCurrentUser
    @State private var archiveName = "Archive"
    @State private var selectedFormat: ArchiveFormat = .zip
    @State private var password = ""
    @State private var splitVolumeSize = ""

    private var formats: [ArchiveFormat] {
        ArchiveFormat.allCases.filter { $0.supportsCreationInUI }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create Archive")
                .font(.title2)
                .fontWeight(.semibold)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Text("Name")
                    TextField("Archive", text: $archiveName)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Format")
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(formats) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                }

                GridRow {
                    Text("Password")
                    SecureField("Optional", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!selectedFormat.supportsEncryption)
                }

                GridRow {
                    Text("Split")
                    TextField("Example: 100m", text: $splitVolumeSize)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Destination")
                    HStack {
                        Text(destinationFolder.path)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Choose") {
                            chooseDestination()
                        }
                    }
                }
            }

            GroupBox {
                VStack(alignment: .leading) {
                    HStack {
                        Text("\(sources.count) item\(sources.count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            chooseSources()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                    List(sources, id: \.self) { source in
                        Text(source.lastPathComponent)
                            .lineLimit(1)
                    }
                    .frame(minHeight: 150)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Create") {
                    workspace.createArchive(CreateArchiveRequest(
                        sources: sources,
                        destinationFolder: destinationFolder,
                        archiveName: archiveName.isEmpty ? "Archive" : archiveName,
                        format: selectedFormat,
                        password: password,
                        splitVolumeSize: splitVolumeSize
                    ))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sources.isEmpty || archiveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 620, height: 520)
        .onAppear {
            let pending = workspace.consumePendingCreateSources()
            guard !pending.isEmpty else { return }
            sources.append(contentsOf: pending)
            if pending.count == 1 {
                archiveName = pending[0].deletingPathExtension().lastPathComponent
                destinationFolder = pending[0].deletingLastPathComponent()
            } else if let first = pending.first {
                archiveName = "Archive"
                destinationFolder = first.deletingLastPathComponent()
            }
        }
    }

    private func chooseSources() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            sources.append(contentsOf: panel.urls)
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            destinationFolder = url
        }
    }
}
