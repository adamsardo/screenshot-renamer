import SwiftUI
import AppKit

@main
struct ScreenshotRenamerApp: App {
    @State private var workspace = Workspace()
    var body: some Scene {
        Window("Screenshot Renamer", id: "main") {
            WorkspaceView(workspace: workspace)
                .frame(minWidth: 920, minHeight: 560)
        }
        .defaultSize(width: 1180, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Images…") { workspace.add(folder: false) }.keyboardShortcut("o").disabled(workspace.busy)
                Button("Add Folder…") { workspace.add(folder: true) }.keyboardShortcut("o", modifiers: [.command, .shift]).disabled(workspace.busy)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Rename Batch") { if let batch = workspace.undoBatch { workspace.restore(batch, forward: false) } }
                    .keyboardShortcut("z").disabled(workspace.busy || workspace.undoBatch == nil)
                Button("Redo Rename Batch") { if let batch = workspace.redoBatch { workspace.restore(batch, forward: true) } }
                    .keyboardShortcut("z", modifiers: [.command, .shift]).disabled(workspace.busy || workspace.redoBatch == nil)
            }
            CommandMenu("Images") {
                Button("Generate Names") { workspace.generate() }.keyboardShortcut("g").disabled(!workspace.canGenerate)
                Button("Preview Image") { workspace.showingPreview = true }.keyboardShortcut(" ", modifiers: []).disabled(workspace.selected == nil)
                Button("Show History") { workspace.showingHistory = true }.keyboardShortcut("h", modifiers: [.command, .shift])
                Divider()
                Button("Include All") { workspace.includeAll(true) }.disabled(workspace.busy)
                Button("Exclude All") { workspace.includeAll(false) }.disabled(workspace.busy)
                Button("Remove Selected from List") { workspace.removeSelected() }.disabled(workspace.busy || workspace.selected == nil)
                Button("Clear List") { workspace.clearList() }.disabled(workspace.busy)
            }
        }
        Settings {
            VStack(alignment: .leading, spacing: 16) {
                Text("Local by design").font(.title2.bold())
                Text("Screenshot Renamer uses the Apple Intelligence model on your Mac. It has no account, API key, analytics or network connection.")
                Text("Names use a description followed by the capture date. When capture information is unavailable, the file creation date is shown as a fallback.")
                Text("History stores filenames and file fingerprints locally so changes can be undone. Images and recognised text are not saved in history.")
                Button("Refresh Apple Intelligence Status") { workspace.refreshModel() }
                Text(workspace.modelStatus).font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(width: 460)
        }
    }
}
