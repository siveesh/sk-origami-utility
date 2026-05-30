import SwiftUI

struct DiskImageQueueView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    private var stagedCount: Int {
        workspace.diskImageJobs.filter { $0.state == .staged }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Disk Images", systemImage: "opticaldiscdrive")
                    .font(.headline)
                Spacer()
                if workspace.diskImageJobs.contains(where: isFinished) {
                    Button("Clear") {
                        workspace.clearFinishedDiskImageJobs()
                    }
                    .controlSize(.small)
                }
                Button {
                    workspace.setAllStagedDiskImageJobs(to: .dmg)
                } label: {
                    Text("DMG")
                }
                .controlSize(.small)
                .disabled(stagedCount == 0)

                Button {
                    workspace.setAllStagedDiskImageJobs(to: .iso)
                } label: {
                    Text("ISO")
                }
                .controlSize(.small)
                .disabled(stagedCount == 0)

                Button {
                    workspace.startDiskImageJobs()
                } label: {
                    Label("Create", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(stagedCount == 0)
            }

            VStack(spacing: 8) {
                ForEach(workspace.diskImageJobs) { job in
                    DiskImageJobRow(job: job) {
                        workspace.removeDiskImageJob(job)
                    }
                }
            }
        }
        .padding()
    }

    private func isFinished(_ job: DiskImageJob) -> Bool {
        switch job.state {
        case .done, .failed:
            true
        default:
            false
        }
    }
}

private struct DiskImageJobRow: View {
    @ObservedObject var job: DiskImageJob
    let onRemove: () -> Void

    @State private var editingName = ""
    @State private var didInitEdit = false

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Label(job.sourceFolderName, systemImage: "folder.fill")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(minWidth: 120, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120)
                        .disabled(job.state != .staged)
                        .onSubmit(commitName)
                        .onAppear {
                            guard !didInitEdit else { return }
                            editingName = job.outputName
                            didInitEdit = true
                        }
                        .onChange(of: editingName) { _, newValue in
                            job.outputName = newValue
                                .replacingOccurrences(of: "/", with: "")
                                .replacingOccurrences(of: "\\", with: "")
                        }
                        .onChange(of: job.outputName) { _, newValue in
                            if editingName != newValue {
                                editingName = newValue
                            }
                        }

                    Picker("Format", selection: $job.format) {
                        ForEach(DiskImageFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 92)
                    .disabled(job.state != .staged)
                }

                HStack(spacing: 8) {
                    if job.windowsContent {
                        Label("Windows content detected", systemImage: "desktopcomputer")
                            .foregroundStyle(.orange)
                    }
                    if !job.note.isEmpty && !job.windowsContent {
                        Text(job.note)
                            .foregroundStyle(.secondary)
                    }
                    if case .failed(let message) = job.state {
                        Text(message)
                            .foregroundStyle(.red)
                    } else {
                        Text(job.state.message)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .lineLimit(2)
            }

            Spacer()

            if let url = job.outputURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Remove")
            .disabled(job.state != .staged)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.state {
        case .staged:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .queued:
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
        case .creating:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private func commitName() {
        let clean = DiskImageService.sanitize(editingName)
        editingName = clean
        job.outputName = clean
    }
}

