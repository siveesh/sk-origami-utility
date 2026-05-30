import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.defaultExtractSameLocation) private var sameLocation = true
    @AppStorage(PreferenceKeys.filterUnnecessaryFiles) private var filterUnnecessaryFiles = true
    @AppStorage(PreferenceKeys.moveArchiveToTrashAfterExtraction) private var moveArchiveToTrash = false
    @AppStorage(PreferenceKeys.moveFolderToTrashAfterDiskImageCreation) private var moveFolderToTrash = false
    @AppStorage(PreferenceKeys.quitAfterLastWindowCloses) private var quitAfterLastWindowCloses = false
    private let archiveService = ArchiveService()
    private let diskImageService = DiskImageService()

    var body: some View {
        TabView {
            Form {
                Section("Extraction") {
                    Toggle("Same Location as Archive", isOn: $sameLocation)
                    Toggle("Filter .DS_Store and __MACOSX", isOn: $filterUnnecessaryFiles)
                    Toggle("Move Archive to Trash", isOn: $moveArchiveToTrash)
                }

                Section("Disk Images") {
                    Toggle("Move Source Folder to Trash", isOn: $moveFolderToTrash)
                }

                Section("Windows") {
                    Toggle("Quit After Last Window Closes", isOn: $quitAfterLastWindowCloses)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            FileAssociationsSettingsView()
                .tabItem {
                    Label("File Associations", systemImage: "doc.badge.gearshape")
                }

            LocalToolsSettingsView(archiveService: archiveService, diskImageService: diskImageService)
                .tabItem {
                    Label("Local Tools", systemImage: "wrench.and.screwdriver")
                }
        }
        .padding()
        .frame(width: 620, height: 460)
    }
}

struct FileAssociationsSettingsView: View {
    private let fileAssociationService = FileAssociationService()
    @State private var associationMessage = ""

    private var supportedFormats: [ArchiveFormat] {
        [.zip, .sevenZip, .rar, .rar5, .tar, .tarGzip, .tarXz, .tarBzip2, .gzip, .jar, .apk, .drfx, .tnef]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Default Archive App")
                        .font(.headline)
                    Text(associationMessage.isEmpty ? "Make SK Origami open supported archives from Finder." : associationMessage)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    let result = fileAssociationService.makeSKOrigamiDefaultArchiveApp()
                    associationMessage = result.message
                } label: {
                    Label("Set Default", systemImage: "checkmark.seal")
                }
            }

            Divider()

            Table(supportedFormats) {
                TableColumn("Format") { format in
                    Label(format.displayName, systemImage: iconName(for: format))
                }
                TableColumn("Extension") { format in
                    Text(".\(format.preferredExtension)")
                        .foregroundStyle(.secondary)
                }
                TableColumn("Support") { format in
                    Text(supportSummary(for: format))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    private func supportSummary(for format: ArchiveFormat) -> String {
        switch format {
        case .drfx:
            "ZIP-compatible: create, inspect, modify, extract"
        case .zip, .jar:
            "Create, inspect, modify, extract"
        case .apk:
            "Inspect and extract"
        case .sevenZip:
            "Create/extract with 7z or 7zz"
        case .rar:
            "Extraction only with bundled 7zz/unar"
        case .rar5:
            "Extraction only with bundled 7zz/unar"
        case .tar, .tarGzip, .tarXz, .tarBzip2:
            "Create, inspect, extract"
        case .gzip:
            "Create and extract single files"
        case .tnef:
            "Extract winmail.dat with tnef"
        case .unknown:
            "Unavailable"
        }
    }

    private func iconName(for format: ArchiveFormat) -> String {
        switch format {
        case .drfx:
            "film.stack"
        case .apk:
            "app.badge"
        case .tnef:
            "envelope"
        default:
            "archivebox"
        }
    }
}

struct LocalToolsSettingsView: View {
    let archiveService: ArchiveService
    let diskImageService: DiskImageService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Local Tools")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                ForEach(archiveService.tools + [diskImageService.toolAvailability], id: \.name) { tool in
                    GridRow {
                        Image(systemName: tool.isAvailable ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(tool.isAvailable ? .green : .secondary)
                        Text(tool.name)
                        Text(tool.displayLocation)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}
