import SwiftUI

struct PasswordVaultView: View {
    @EnvironmentObject private var workspace: ArchiveWorkspaceStore

    var body: some View {
        List {
            ForEach(workspace.passwordRecords) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.archiveName)
                        .fontWeight(.medium)
                    Text("\(record.format.displayName) - \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(record.password)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .onDelete(perform: workspace.deletePasswordRecords)
        }
    }
}
