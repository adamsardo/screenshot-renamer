import Testing
import Foundation
import Darwin
@testable import RenamerCore

struct FilenameTests {
    @Test func captureDates() {
        #expect(CaptureDate.resolve(filename: "CleanShot 2026-09-06 at 11.45.12@2x.png")?.value == "2026-09-06")
        #expect(CaptureDate.resolve(filename: "Screenshot 2024-02-29 at 10.00.png")?.value == "2024-02-29")
        #expect(CaptureDate.resolve(filename: "CleanShot 2025-02-29.png") == nil)
        #expect(CaptureDate.resolve(filename: "random 2026-09-06.png") == nil)
        #expect(CaptureDate.resolve(filename: "image.jpg", metadata: "2022:01:03 10:11:12")?.source == "Image capture metadata")
    }
    @Test func safeNames() throws {
        let date = CaptureDate(value: "2026-09-06", source: "test")
        #expect(try FilenamePolicy.compose(title: "../My: app\nsettings", date: date, extension: "PNG") == "My app settings — 2026-09-06.PNG")
        #expect(try FilenamePolicy.compose(title: String(repeating: "🧑🏽‍💻", count: 100), date: date, extension: "png").utf8.count <= 240)
        #expect(FilenamePolicy.key("Café") == FilenamePolicy.key("CAFE\u{301}"))
        #expect(throws: (any Error).self) { try FilenamePolicy.validate("../secret") }
        let name = try FilenamePolicy.compose(title: "Settings", date: date, extension: "png")
        #expect(try FilenamePolicy.propose(title: "Settings", date: date, extension: "png", occupied: [FilenamePolicy.key(name)]) == "Settings — 2026-09-06 (2).png")
    }
}

struct SafetyTests {
    func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func request(_ directory: URL, original: String = "original.png", name: String = "renamed.png") throws -> RenameRequest {
        let url = directory.appendingPathComponent(original)
        try Data("unchanged image bytes".utf8).write(to: url)
        return RenameRequest(source: url, name: name, fingerprint: try Fingerprint.read(url))
    }
    @Test func renameUndoRedoAndRelaunch() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let journal = directory.appendingPathComponent("history.json")
        let engine = RenameEngine(journalURL: journal)
        let batch = try await engine.apply([request])
        #expect(batch.entries[0].location == .renamed)
        #expect(try Fingerprint.read(batch.entries[0].renamed) == request.fingerprint)
        let reopened = RenameEngine(journalURL: journal)
        let history = try await reopened.history()
        #expect(history.count == 1)
        let undo = try await reopened.restore(batchID: batch.id, forward: false)
        #expect(undo.entries[0].location == .original)
        #expect(try Fingerprint.read(request.source) == request.fingerprint)
        let redo = try await reopened.restore(batchID: batch.id, forward: true)
        #expect(redo.entries[0].location == .renamed)
    }
    @Test func lateCollisionNeverOverwrites() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let destination = directory.appendingPathComponent(request.name)
        try Data("keep me".utf8).write(to: destination)
        let engine = RenameEngine(journalURL: directory.appendingPathComponent("history.json"))
        let batch = try await engine.apply([request])
        #expect(batch.entries[0].location == .original)
        #expect(batch.entries[0].error != nil)
        #expect(try String(contentsOf: destination, encoding: .utf8) == "keep me")
        #expect(try Fingerprint.read(request.source) == request.fingerprint)
    }
    @Test func changedSourceAndPartialFailure() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let changed = try request(directory)
        let valid = try request(directory, original: "second.png", name: "second-renamed.png")
        try Data("changed".utf8).write(to: changed.source)
        let batch = try await RenameEngine(journalURL: directory.appendingPathComponent("history.json")).apply([changed, valid])
        #expect(batch.entries[0].location == .original)
        #expect(batch.entries[0].error != nil)
        #expect(batch.entries[1].location == .renamed)
    }
    @Test func undoConflictAndChangedContents() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let engine = RenameEngine(journalURL: directory.appendingPathComponent("history.json"))
        let batch = try await engine.apply([request])
        try Data("new file".utf8).write(to: request.source)
        let undo = try await engine.restore(batchID: batch.id, forward: false)
        #expect(undo.entries[0].location == .renamed)
        #expect(undo.entries[0].error != nil)
        #expect(try String(contentsOf: request.source, encoding: .utf8) == "new file")
    }
    @Test func symlinksRejected() throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let link = directory.appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: request.source)
        #expect(throws: (any Error).self) { try Fingerprint.read(link) }
    }
    @Test func duplicateTargetsAndExtensionChangeRejected() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let first = try request(directory)
        let second = try request(directory, original: "second.png", name: "RENAMED.png")
        let engine = RenameEngine(journalURL: directory.appendingPathComponent("history.json"))
        await #expect(throws: (any Error).self) { try await engine.apply([first, second]) }
        let invalid = RenameRequest(source: first.source, name: "renamed.jpg", fingerprint: first.fingerprint)
        await #expect(throws: (any Error).self) { try await engine.apply([invalid]) }
    }
    @Test func recoverCrashBetweenMoveAndJournalCompletion() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let destination = directory.appendingPathComponent(request.name)
        let journal = directory.appendingPathComponent("history.json")
        let batch = RenameBatch(id: UUID(), date: Date(), entries: [HistoryEntry(id: UUID(), original: request.source, renamed: destination, fingerprint: request.fingerprint, location: .original, pending: true)])
        try JSONEncoder().encode([batch]).write(to: journal)
        try FileManager.default.moveItem(at: request.source, to: destination)
        let engine = RenameEngine(journalURL: journal)
        let recovered = try await engine.reconcile()
        #expect(recovered[0].entries[0].location == .renamed)
        #expect(!recovered[0].entries[0].pending)
        let undone = try await engine.restore(batchID: batch.id, forward: false)
        #expect(undone.entries[0].location == .original)
    }
    @Test func ambiguousRecoveryDoesNotGuess() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let journal = directory.appendingPathComponent("history.json")
        let batch = RenameBatch(id: UUID(), date: Date(), entries: [HistoryEntry(id: UUID(), original: request.source, renamed: directory.appendingPathComponent(request.name), fingerprint: request.fingerprint, location: .original, pending: true)])
        try JSONEncoder().encode([batch]).write(to: journal)
        try FileManager.default.removeItem(at: request.source)
        let engine = RenameEngine(journalURL: journal)
        let recovered = try await engine.reconcile()
        #expect(recovered[0].entries[0].location == .uncertain)
        await #expect(throws: (any Error).self) { try await engine.clearHistory() }
    }
    @Test func caseAndUnicodeCollisionsAreProtected() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory, name: "Café.png")
        try Data("existing".utf8).write(to: directory.appendingPathComponent("CAFE\u{301}.png"))
        let batch = try await RenameEngine(journalURL: directory.appendingPathComponent("history.json")).apply([request])
        #expect(batch.entries[0].location == .original)
        #expect(batch.entries[0].error != nil)
    }
    @Test func corruptedJournalFailsClosed() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let journal = directory.appendingPathComponent("history.json")
        try Data("corrupt history".utf8).write(to: journal)
        let engine = RenameEngine(journalURL: journal)
        await #expect(throws: (any Error).self) { try await engine.apply([request]) }
        #expect(try Fingerprint.read(request.source) == request.fingerprint)
        #expect(try String(contentsOf: journal, encoding: .utf8) == "corrupt history")
    }
    @Test func lockedFileIsNotRenamed() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        #expect(chflags(request.source.path, UInt32(UF_IMMUTABLE)) == 0)
        defer { _ = chflags(request.source.path, 0) }
        let batch = try await RenameEngine(journalURL: directory.appendingPathComponent("history.json")).apply([request])
        #expect(batch.entries[0].location == .original)
        #expect(batch.entries[0].error != nil)
        #expect(try Fingerprint.read(request.source) == request.fingerprint)
    }
    @Test func metadataSurvivesRenameAndUndo() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let attribute = "preserve metadata"
        let result = attribute.withCString { setxattr(request.source.path, "io.github.screenshot-renamer.test", $0, attribute.utf8.count, 0, 0) }
        #expect(result == 0)
        let before = try FileManager.default.attributesOfItem(atPath: request.source.path)
        let engine = RenameEngine(journalURL: directory.appendingPathComponent("history.json"))
        let batch = try await engine.apply([request])
        let restored = try await engine.restore(batchID: batch.id, forward: false)
        #expect(restored.entries[0].location == .original)
        let after = try FileManager.default.attributesOfItem(atPath: request.source.path)
        #expect(before[.creationDate] as? Date == after[.creationDate] as? Date)
        #expect(before[.modificationDate] as? Date == after[.modificationDate] as? Date)
        #expect(getxattr(request.source.path, "io.github.screenshot-renamer.test", nil, 0, 0, 0) == attribute.utf8.count)
    }
    @Test func crashBeforeMoveRecoversOriginal() async throws {
        let directory = try fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let request = try request(directory)
        let journal = directory.appendingPathComponent("history.json")
        let batch = RenameBatch(id: UUID(), date: Date(), entries: [HistoryEntry(id: UUID(), original: request.source, renamed: directory.appendingPathComponent(request.name), fingerprint: request.fingerprint, location: .original, pending: true)])
        try JSONEncoder().encode([batch]).write(to: journal)
        let recovered = try await RenameEngine(journalURL: journal).reconcile()
        #expect(recovered[0].entries[0].location == .original)
        #expect(!recovered[0].entries[0].pending)
    }

}
