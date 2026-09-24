import SwiftUI
import AppKit
import RenamerCore

struct WorkspaceView: View {
    @Bindable var workspace: Workspace
    @State private var confirmRename = false
    var body: some View {
        VStack(spacing: 0) {
            if workspace.rows.isEmpty {
                emptyState
            } else {
                HSplitView {
                    imageTable.frame(minWidth: 510)
                    inspector.frame(minWidth: 300, idealWidth: 360, maxWidth: 470)
                }
            }
            Divider()
            HStack(spacing: 12) {
                if workspace.busy { ProgressView().controlSize(.small) }
                Text(workspace.message).lineLimit(2)
                Spacer()
                if !workspace.skipped.isEmpty { Button("Skipped items (\(workspace.skipped.count))") { workspace.showingSkipped = true } }
                if workspace.busy { Button("Cancel") { workspace.cancel() }.disabled(workspace.mutating) }
            }.font(.callout).padding(12).background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { workspace.add(folder: false) } label: { Label("Add Images", systemImage: "photo.badge.plus") }.disabled(workspace.busy)
                Button { workspace.add(folder: true) } label: { Label("Add Folder", systemImage: "folder.badge.plus") }.disabled(workspace.busy)
                Divider()
                Button { workspace.generate() } label: { Label("Generate Names", systemImage: "sparkles") }.disabled(!workspace.canGenerate)
                Button { confirmRename = true } label: { Text("Rename \(workspace.eligible.count) Images") }.disabled(workspace.busy || workspace.eligible.isEmpty)
                Button { workspace.showingHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !workspace.busy else { return false }
            workspace.importItems(urls); return true
        }
        .alert("Rename reviewed images?", isPresented: $confirmRename) {
            Button("Cancel", role: .cancel) {}
            Button("Rename \(workspace.eligible.count) Images") { workspace.apply() }
        } message: { Text("Apply the proposed names to \(workspace.eligible.count) included images in their current folders. You can undo this batch from History.") }
        .alert("Something needs attention", isPresented: Binding(get: { workspace.alert != nil }, set: { if !$0 { workspace.alert = nil } })) {
            Button("OK") { workspace.alert = nil }
        } message: { Text(workspace.alert ?? "") }
        .sheet(isPresented: $workspace.showingHistory) { HistoryView(workspace: workspace) }
        .sheet(isPresented: $workspace.showingSkipped) {
            VStack(alignment: .leading) {
                Text("Skipped items").font(.title2.bold())
                Text("Download unavailable files in Finder, then add them again. Folders are not searched recursively.").foregroundStyle(.secondary)
                List(workspace.skipped, id: \.self) { Text($0).textSelection(.enabled) }
                HStack { Spacer(); Button("Done") { workspace.showingSkipped = false }.keyboardShortcut(.defaultAction) }
            }.padding(20).frame(width: 650, height: 420)
        }
        .sheet(isPresented: $workspace.showingPreview) {
            VStack {
                if let row = workspace.selected {
                    ImagePreview(url: row.url).frame(minWidth: 700, minHeight: 450)
                    Text(row.url.lastPathComponent).textSelection(.enabled)
                }
                Button("Done") { workspace.showingPreview = false }.keyboardShortcut(.defaultAction)
            }.padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 56, weight: .light)).foregroundStyle(.tint)
            Text("Find your screenshots by name").font(.largeTitle.bold())
            Text("Add images. Generate descriptions on your Mac.\nReview the names, then rename them together.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack { Button("Add Images…") { workspace.add(folder: false) }; Button("Add Folder…") { workspace.add(folder: true) } }.controlSize(.large)
            Toggle("Only include CleanShot images when adding folders", isOn: $workspace.cleanShotOnly).toggleStyle(.checkbox).padding(.top, 10)
            Text("Or drop images or folders here").foregroundStyle(.tertiary)
            Label(workspace.modelStatus, systemImage: workspace.modelAvailable ? "checkmark.shield" : "exclamationmark.circle")
                .font(.callout).foregroundStyle(.secondary).padding(.top, 16)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(32)
    }

    private var imageTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(workspace.rows.count) images").font(.headline)
                Spacer()
                Menu("Selection") {
                    Button("Include All") { workspace.includeAll(true) }
                    Button("Exclude All") { workspace.includeAll(false) }
                    Button("Remove Selected from List") { workspace.removeSelected() }
                    Button("Clear List") { workspace.clearList() }
                }.disabled(workspace.busy)
            }.padding(12)
            Table(workspace.rows, selection: $workspace.selection) {
                TableColumn("") { row in
                    Toggle("Include \(row.url.lastPathComponent)", isOn: Binding(get: { row.included }, set: { workspace.include(id: row.id, value: $0) }))
                        .labelsHidden().disabled(workspace.busy || row.renamed)
                }.width(28)
                TableColumn("Current name") { row in Text(row.url.lastPathComponent).help(row.url.lastPathComponent) }.width(min: 160, ideal: 210)
                TableColumn("Proposed name") { row in
                    Text(row.proposed.isEmpty ? "—" : row.proposed).foregroundStyle(row.proposed.isEmpty ? .secondary : .primary).help(row.proposed)
                }.width(min: 170, ideal: 260)
                TableColumn("Status") { row in
                    Text(row.renamed ? "Renamed" : workspace.needsAccess(row) ? "Folder access needed" : row.status).font(.callout)
                }.width(min: 110, ideal: 140)
            }
        }
    }

    @ViewBuilder private var inspector: some View {
        if let row = workspace.selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ImagePreview(url: row.url).frame(height: 230).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                        .onTapGesture(count: 2) { workspace.showingPreview = true }
                    HStack { Text("Review name").font(.title2.bold()); Spacer(); Button { workspace.showingPreview = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Preview image") }
                    Text(row.url.lastPathComponent).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    TextField("Description", text: Binding(get: { workspace.selected?.title ?? "" }, set: { workspace.edit(id: row.id, title: $0) }), axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(2...4).disabled(workspace.busy || row.renamed).accessibilityLabel("Filename description")
                    if let date = row.date {
                        LabeledContent("Capture date", value: date.value)
                        Text(date.source).font(.caption).foregroundStyle(.secondary)
                    } else { Text("No capture date is available. This image cannot be renamed.").foregroundStyle(.secondary) }
                    if !row.proposed.isEmpty {
                        Text("Proposed filename").font(.caption.bold()).foregroundStyle(.secondary)
                        Text(row.proposed).font(.callout).textSelection(.enabled)
                    }
                    Divider()
                    Text(row.status).font(.callout).foregroundStyle(.secondary)
                    if workspace.needsAccess(row) {
                        Text("Choose the containing folder to allow renaming and undo.").font(.callout)
                        Button("Allow Folder Access…") { workspace.grantFolder(for: row.url) }.disabled(workspace.busy)
                    }
                    Button(row.title.isEmpty ? "Generate Name" : "Regenerate Name") { workspace.generate(only: row.id) }
                        .disabled(workspace.busy || !workspace.modelAvailable || row.renamed)
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([row.url]) }
                    Text("Suggestions can be inaccurate. Check the image and remove any private details before applying.").font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
        } else {
            ContentUnavailableView("Select an image", systemImage: "photo", description: Text("Preview it and edit its description here."))
        }
    }
}

struct ImagePreview: View {
    let url: URL
    @State private var image: CGImage?
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFit().accessibilityLabel("Selected screenshot preview") }
            else { ContentUnavailableView("Preview unavailable", systemImage: "photo") }
        }
        .task(id: url) {
            image = nil
            let result = await Task.detached { ImageServices.thumbnail(url) }.value
            if !Task.isCancelled { image = result }
        }
    }
}
