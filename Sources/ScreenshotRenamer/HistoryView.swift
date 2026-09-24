import SwiftUI
import RenamerCore

struct HistoryView: View {
    @Bindable var workspace: Workspace
    @State private var confirmClear = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Rename history").font(.title2.bold())
                Spacer()
                Button("Recheck Recovery") { Task { await workspace.refreshHistory(reconcile: true) } }.disabled(workspace.busy)
            }
            Text("History stays on this Mac. Undo restores original names only when the file is unchanged and the original name is free.").foregroundStyle(.secondary)
            if workspace.batches.isEmpty {
                ContentUnavailableView("No renames yet", systemImage: "clock.arrow.circlepath").frame(maxHeight: .infinity)
            } else {
                List(workspace.batches.reversed()) { batch in
                    DisclosureGroup {
                        ForEach(batch.entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.original.lastPathComponent).font(.caption)
                                Text("→ \(entry.renamed.lastPathComponent)").textSelection(.enabled)
                                Text(entry.pending ? "Interrupted — recheck recovery" : entry.location == .renamed ? "Renamed" : entry.location == .original ? "At original name" : "Needs recovery").font(.caption).foregroundStyle(.secondary)
                                if let error = entry.error {
                                    Text(error).font(.caption).foregroundStyle(.orange)
                                    Button("Allow Folder Access…") { workspace.grantFolder(for: entry.original) }.disabled(workspace.busy)
                                }
                            }.padding(.vertical, 4)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(batch.date.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                                Text("\(batch.entries.count) images").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Undo") { workspace.restore(batch, forward: false) }.disabled(workspace.busy || !batch.entries.contains { $0.location == .renamed && !$0.pending })
                            Button("Redo / Retry") { workspace.restore(batch, forward: true) }.disabled(workspace.busy || !batch.entries.contains { $0.location == .original && !$0.pending })
                        }
                    }
                }
            }
            HStack {
                Button("Clear History…", role: .destructive) { confirmClear = true }.disabled(workspace.busy || workspace.batches.isEmpty)
                Spacer()
                Button("Done") { workspace.showingHistory = false }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 760, height: 540)
        .confirmationDialog("Clear all rename history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { workspace.clearHistory() }
        } message: { Text("Files will keep their current names. You will no longer be able to undo these batches. Interrupted operations must be recovered first.") }
    }
}
