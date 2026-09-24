import AppKit
import SwiftUI
import FoundationModels
import RenamerCore

struct ImageRow: Identifiable {
    let id = UUID()
    var url: URL
    let fingerprint: Fingerprint
    let date: CaptureDate?
    var included = true
    var title = ""
    var proposed = ""
    var edited = false
    var status = "Ready"
    var renamed = false
}

@MainActor @Observable
final class Workspace {
    var rows: [ImageRow] = []
    var selection: Set<UUID> = []
    var busy = false
    var mutating = false
    var message = "Add screenshots to get started."
    var alert: String?
    var skipped: [String] = []
    var showingSkipped = false
    var showingHistory = false
    var showingPreview = false
    var cleanShotOnly = false
    var batches: [RenameBatch] = []
    var modelStatus = "Checking Apple Intelligence…"
    var modelAvailable = false
    private var job: Task<Void, Never>?
    private var picker: NSOpenPanel?
    private let access = FolderAccess()
    private let naming = AppleNamingService()
    private let engine: RenameEngine
    private var occupancy: [URL: Set<String>] = [:]

    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ScreenshotRenamer")
        engine = RenameEngine(journalURL: root.appendingPathComponent("history.json"))
        refreshModel()
        Task { await refreshHistory(reconcile: true) }
    }
    var selected: ImageRow? { rows.first { selection.contains($0.id) } }
    var eligible: [ImageRow] { rows.filter { $0.included && !$0.renamed && !$0.proposed.isEmpty && $0.proposed != $0.url.lastPathComponent && access.permits($0.url) } }
    var canGenerate: Bool { modelAvailable && !busy && rows.contains { $0.included && !$0.renamed && !$0.edited && $0.title.isEmpty } }
    var undoBatch: RenameBatch? { batches.last { $0.entries.contains { $0.location == .renamed && !$0.pending } } }
    var redoBatch: RenameBatch? { batches.last { $0.lastRestoreForward == false && $0.entries.contains { $0.location == .original && !$0.pending } } }

    private var textUndo: UndoManager? {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isEditable else { return nil }
        return editor.undoManager
    }
    var canUndo: Bool { textUndo.map { $0.canUndo } ?? (undoBatch != nil) }
    var canRedo: Bool { textUndo.map { $0.canRedo } ?? (redoBatch != nil) }
    func undo() {
        if let manager = textUndo { manager.undo() }
        else if let batch = undoBatch { restore(batch, forward: false) }
    }
    func redo() {
        if let manager = textUndo { manager.redo() }
        else if let batch = redoBatch { restore(batch, forward: true) }
    }

    func refreshModel() {
        switch SystemLanguageModel.default.availability {
        case .available: modelAvailable = true; modelStatus = "Apple Intelligence · On device"
        case .unavailable(let reason): modelAvailable = false; modelStatus = "Apple Intelligence unavailable (\(reason)). You can enter names manually."
        }
    }
    func add(folder: Bool) {
        guard !busy, picker == nil else { return }
        let panel = NSOpenPanel()
        picker = panel
        panel.canChooseDirectories = folder; panel.canChooseFiles = !folder
        panel.allowsMultipleSelection = true
        panel.message = folder ? "Choose a folder containing images. Subfolders are not included." : "Choose PNG, JPEG or HEIC screenshots. Folder access is needed to apply new names."
        panel.prompt = "Add"
        panel.begin { [weak self] response in
            guard let self else { return }
            self.picker = nil
            guard response == .OK else { return }
            self.importItems(panel.urls, grantedFolder: folder)
        }
    }
    func grantFolder(for url: URL) {
        guard !busy, picker == nil else { return }
        let panel = NSOpenPanel()
        picker = panel
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.directoryURL = url.deletingLastPathComponent()
        panel.message = "Allow access to the containing folder so Screenshot Renamer can rename files and undo changes."
        panel.prompt = "Allow Folder Access"
        panel.begin { [weak self] response in
            guard let self else { return }
            self.picker = nil
            guard response == .OK, let folder = panel.url else { return }
            do { try self.access.retain(folder, folder: true); self.replan(); Task { await self.refreshHistory(reconcile: true) } }
            catch { self.alert = error.localizedDescription }
        }
    }
    func needsAccess(_ row: ImageRow) -> Bool { !access.permits(row.url) }

    func importItems(_ urls: [URL], grantedFolder: Bool = false) {
        guard !busy else { return }
        for url in urls {
            let isFolder = grantedFolder || ((try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true)
            do { try access.retain(url, folder: isFolder) } catch { alert = error.localizedDescription }
        }
        busy = true; message = "Reading images…"
        let filter = cleanShotOnly
        job = Task {
            let importTask = Task.detached(priority: .userInitiated) { ImageServices.importURLs(urls, cleanShotOnly: filter) }
            let imported = await withTaskCancellationHandler { await importTask.value } onCancel: { importTask.cancel() }
            let existing = Set(rows.map { "\($0.fingerprint.device):\($0.fingerprint.inode)" })
            var seen = existing
            for image in imported.images {
                if seen.insert("\(image.fingerprint.device):\(image.fingerprint.inode)").inserted {
                    rows.append(ImageRow(url: image.url, fingerprint: image.fingerprint, date: image.date))
                }
            }
            skipped = imported.skipped
            if selection.isEmpty, let first = rows.first { selection = [first.id] }
            await refreshOccupancy()
            busy = false; job = nil
            message = (Task.isCancelled ? "Import cancelled. " : "") + "\(rows.count) images added" + (skipped.isEmpty ? "." : " · \(skipped.count) items skipped.")
        }
    }
    func edit(id: UUID, title: String) {
        guard let index = rows.firstIndex(where: { $0.id == id }), !busy, !rows[index].renamed else { return }
        rows[index].title = title; rows[index].edited = true; rows[index].status = "Edited"
        replan()
    }
    func include(id: UUID, value: Bool) {
        guard let index = rows.firstIndex(where: { $0.id == id }), !busy else { return }
        rows[index].included = value; replan()
    }
    func includeAll(_ value: Bool) { guard !busy else { return }; for i in rows.indices { rows[i].included = value }; replan() }
    func removeSelected() { guard !busy else { return }; rows.removeAll { selection.contains($0.id) }; selection = rows.first.map { [$0.id] } ?? []; replan() }
    func clearList() { guard !busy else { return }; rows.removeAll(); selection = []; message = "Add screenshots to get started." }

    func generate(only id: UUID? = nil) {
        guard !busy, modelAvailable else { return }
        let targets = rows.filter { !$0.renamed && (id == nil ? ($0.included && !$0.edited && $0.title.isEmpty) : $0.id == id) }
        guard !targets.isEmpty else { return }
        busy = true
        job = Task {
            var done = 0
            for row in targets {
                if Task.isCancelled { break }
                message = "Naming \(done + 1) of \(targets.count)…"
                guard let index = rows.firstIndex(where: { $0.id == row.id }) else { continue }
                rows[index].status = "Analysing…"
                do {
                    let title = try await naming.suggest(url: row.url, expected: row.fingerprint)
                    if Task.isCancelled { rows[index].status = "Cancelled"; break }
                    rows[index].title = title; rows[index].edited = false; rows[index].status = "Review suggestion"
                } catch {
                    rows[index].status = Task.isCancelled ? "Cancelled" : "Enter a name manually"
                    if !Task.isCancelled { message = "Apple Intelligence could not name an image. You can enter a name manually." }
                }
                done += 1; replan()
            }
            message = Task.isCancelled ? "Cancelled. Completed suggestions are ready to review." : "\(done) images processed. Review the suggestions before renaming."
            busy = false; job = nil
        }
    }
    func cancel() { job?.cancel(); message = "Stopping after the current operation…" }

    private func refreshOccupancy() async {
        let folders = Set(rows.map { $0.url.deletingLastPathComponent() })
        occupancy = await Task.detached {
            Dictionary(uniqueKeysWithValues: folders.map { folder in
                (folder, Set(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).map(FilenamePolicy.key)))
            })
        }.value
        replan()
    }
    private func replan() {
        var occupied = occupancy
        for i in rows.indices {
            guard !rows[i].renamed else { continue }
            rows[i].proposed = ""
            guard !rows[i].title.isEmpty else { continue }
            guard let date = rows[i].date else { rows[i].status = "Capture date unavailable"; continue }
            let folder = rows[i].url.deletingLastPathComponent()
            var names = occupied[folder] ?? []
            names.remove(FilenamePolicy.key(rows[i].url.lastPathComponent))
            do {
                let proposal = try FilenamePolicy.propose(title: rows[i].title, date: date, extension: rows[i].url.pathExtension, occupied: names)
                rows[i].proposed = proposal
                if rows[i].included { occupied[folder, default: []].insert(FilenamePolicy.key(proposal)) }
            } catch { rows[i].status = error.localizedDescription }
        }
    }
    func apply() {
        guard !busy, !eligible.isEmpty else { return }
        let requests = eligible.map { RenameRequest(source: $0.url, name: $0.proposed, fingerprint: $0.fingerprint) }
        busy = true; mutating = true; message = "Renaming reviewed files…"
        job = Task {
            do {
                let batch = try await engine.apply(requests)
                updateRows(batch)
                let count = batch.entries.filter { $0.location == .renamed }.count
                message = "Renamed \(count) of \(batch.entries.count) images. Undo is available in History."
            } catch { alert = error.localizedDescription }
            await refreshHistory(); await refreshOccupancy()
            busy = false; mutating = false; job = nil
        }
    }
    func restore(_ batch: RenameBatch, forward: Bool) {
        guard !busy else { return }
        busy = true; mutating = true; message = forward ? "Redoing rename…" : "Restoring original names…"
        job = Task {
            do {
                let result = try await engine.restore(batchID: batch.id, forward: forward)
                updateRows(result)
                message = result.entries.contains { $0.error != nil } ? "Some files need attention. See History for details." : (forward ? "Rename reapplied." : "Original names restored.")
            } catch { alert = error.localizedDescription }
            await refreshHistory(); await refreshOccupancy()
            busy = false; mutating = false; job = nil
        }
    }
    private func updateRows(_ batch: RenameBatch) {
        for entry in batch.entries {
            guard let index = rows.firstIndex(where: { $0.fingerprint == entry.fingerprint }) else { continue }
            rows[index].url = entry.location == .renamed ? entry.renamed : entry.original
            rows[index].renamed = entry.location == .renamed
            rows[index].status = entry.error ?? (entry.location == .renamed ? "Renamed" : "Original name restored")
        }
    }
    func refreshHistory(reconcile: Bool = false) async {
        do { batches = try await (reconcile ? engine.reconcile() : engine.history()) }
        catch { alert = error.localizedDescription }
    }
    func clearHistory() {
        Task { do { try await engine.clearHistory(); await refreshHistory() } catch { alert = error.localizedDescription } }
    }
}
