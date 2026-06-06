import SwiftUI

struct ExtractionProgressView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Extracting Archives")
                .font(.title2)
                .fontWeight(.semibold)

            if workspace.extractionJobs.isEmpty {
                ContentUnavailableView("No Extractions", systemImage: "archivebox")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(workspace.extractionJobs) { job in
                            ExtractionProgressRow(job: job)
                            if job.id != workspace.extractionJobs.last?.id {
                                Divider()
                                    .padding(.leading, 34)
                            }
                        }
                    }
                }
                .scrollIndicators(workspace.extractionJobs.count > 8 ? .visible : .hidden)
            }

            HStack {
                Button("Clear Finished") {
                    workspace.clearFinishedExtractionJobs()
                }
                Spacer()
                if workspace.isExtractingArchives {
                    ProgressView()
                        .controlSize(.small)
                    Text("Working...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 560, height: workspace.extractionProgressWindowHeight)
        .sheet(isPresented: $workspace.isShowingExtractionPasswordPrompt) {
            ExtractionPasswordPrompt()
                .environmentObject(workspace)
        }
    }

}

private struct ExtractionProgressRow: View {
    @ObservedObject var job: ExtractionJob

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(job.archive.displayName)
                    .lineLimit(1)
                Text(job.state.label)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
                progressBar
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.state {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        case .waitingForPassword:
            Image(systemName: "key.fill").foregroundStyle(.orange)
        case .extracting, .checkingEncryption:
            ProgressView().controlSize(.small)
        case .queued:
            Image(systemName: "clock").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        switch job.state {
        case .queued:
            ProgressView(value: 0)
        case .checkingEncryption:
            ProgressView(value: 0.1)
        case .waitingForPassword:
            ProgressView(value: 0.1)
                .tint(.orange)
        case .extracting:
            ProgressView()
        case .done:
            ProgressView(value: 1)
                .tint(.green)
        case .failed:
            ProgressView(value: 1)
                .tint(.red)
        }
    }

    private var statusColor: Color {
        switch job.state {
        case .failed: .red
        case .waitingForPassword: .orange
        default: .secondary
        }
    }
}

private struct ExtractionPasswordPrompt: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Password Required")
                .font(.title2)
                .fontWeight(.semibold)
            Text(workspace.pendingPasswordArchiveName)
                .foregroundStyle(.secondary)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") {
                    workspace.cancelQuickExtractionPassword()
                }
                Button("Extract") {
                    workspace.submitQuickExtractionPassword(password)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 420)
        .onAppear {
            password = workspace.savedPasswordForPendingExtraction
        }
    }
}
