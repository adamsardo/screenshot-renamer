import Foundation
import CryptoKit
import Darwin

public struct Fingerprint: Codable, Sendable, Equatable {
    public let device: Int32
    public let inode: UInt64
    public let size: Int64
    public let modifiedSeconds: Int64
    public let modifiedNanoseconds: Int64
    public let digest: String

    public static func read(_ url: URL) throws -> Fingerprint {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard info.st_mode & S_IFMT == S_IFREG else { throw RenameError.unsupported }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return Fingerprint(device: info.st_dev, inode: info.st_ino, size: info.st_size,
                           modifiedSeconds: Int64(info.st_mtimespec.tv_sec), modifiedNanoseconds: Int64(info.st_mtimespec.tv_nsec),
                           digest: hash.finalize().map { String(format: "%02x", $0) }.joined())
    }
}

public struct RenameRequest: Sendable {
    public let source: URL
    public let name: String
    public let fingerprint: Fingerprint
    public init(source: URL, name: String, fingerprint: Fingerprint) {
        self.source = source; self.name = name; self.fingerprint = fingerprint
    }
}

public struct HistoryEntry: Codable, Identifiable, Sendable {
    public enum Location: String, Codable, Sendable { case original, renamed, uncertain }
    public let id: UUID
    public let original: URL
    public let renamed: URL
    public let fingerprint: Fingerprint
    public var location: Location
    public var pending: Bool
    public var error: String?
}

public struct RenameBatch: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public var entries: [HistoryEntry]
}

/// All filesystem mutations and durable journal updates run serially in this actor.
public actor RenameEngine {
    private let journalURL: URL
    private var batches: [RenameBatch] = []
    private var loaded = false

    public init(journalURL: URL) { self.journalURL = journalURL }

    public func history() throws -> [RenameBatch] {
        try load()
        return batches
    }

    public func apply(_ requests: [RenameRequest]) throws -> RenameBatch {
        try load()
        var destinations = Set<String>()
        for request in requests {
            try FilenamePolicy.validate(request.name)
            let destination = request.source.deletingLastPathComponent().appendingPathComponent(request.name)
            guard destination.pathExtension == request.source.pathExtension else { throw RenameError.invalidName("Keep the original extension.") }
            guard destination != request.source else { throw RenameError.invalidName("The name is unchanged.") }
            let key = destination.deletingLastPathComponent().path + "/" + FilenamePolicy.key(request.name)
            guard destinations.insert(key).inserted else { throw RenameError.occupied }
        }
        let batch = RenameBatch(id: UUID(), date: Date(), entries: requests.map {
            HistoryEntry(id: UUID(), original: $0.source,
                         renamed: $0.source.deletingLastPathComponent().appendingPathComponent($0.name),
                         fingerprint: $0.fingerprint, location: .original, pending: false)
        })
        batches.append(batch)
        try persist()
        let index = batches.count - 1
        for item in batches[index].entries.indices {
            if Task.isCancelled { break }
            try move(batch: index, entry: item, forward: true)
        }
        return batches[index]
    }

    public func restore(batchID: UUID, forward: Bool) throws -> RenameBatch {
        try load()
        guard let index = batches.firstIndex(where: { $0.id == batchID }) else { throw RenameError.changed }
        let indices = forward ? Array(batches[index].entries.indices) : Array(batches[index].entries.indices.reversed())
        for item in indices {
            if Task.isCancelled { break }
            let entry = batches[index].entries[item]
            guard !entry.pending, entry.location == (forward ? .original : .renamed) else { continue }
            try move(batch: index, entry: item, forward: forward)
        }
        return batches[index]
    }

    public func reconcile() throws -> [RenameBatch] {
        try load()
        for b in batches.indices {
            for e in batches[b].entries.indices where batches[b].entries[e].pending || batches[b].entries[e].location == .uncertain {
                let entry = batches[b].entries[e]
                let atOriginal = (try? Fingerprint.read(entry.original)) == entry.fingerprint
                let atRenamed = (try? Fingerprint.read(entry.renamed)) == entry.fingerprint
                if atOriginal != atRenamed {
                    batches[b].entries[e].location = atOriginal ? .original : .renamed
                    batches[b].entries[e].pending = false
                    batches[b].entries[e].error = nil
                } else {
                    batches[b].entries[e].location = .uncertain
                    batches[b].entries[e].error = "Recovery needs access to the folder and an unchanged file. No file was moved."
                }
            }
        }
        try persist()
        return batches
    }

    public func clearHistory() throws {
        try load()
        guard !batches.contains(where: { $0.entries.contains(where: { $0.pending || $0.location == .uncertain }) }) else {
            throw RenameError.journal("Resolve interrupted operations before clearing history.")
        }
        batches = []
        try persist()
    }

    private func move(batch b: Int, entry e: Int, forward: Bool) throws {
        let entry = batches[b].entries[e]
        let from = forward ? entry.original : entry.renamed
        let to = forward ? entry.renamed : entry.original
        batches[b].entries[e].pending = true
        batches[b].entries[e].error = nil
        try persist() // intent reaches disk before the filesystem operation
        do {
            try Self.exclusiveMove(from: from, to: to, expected: entry.fingerprint)
            batches[b].entries[e].location = forward ? .renamed : .original
        } catch {
            batches[b].entries[e].error = error.localizedDescription
        }
        batches[b].entries[e].pending = false
        try persist() // a failure here leaves the on-disk intent available for recovery
    }

    private static func exclusiveMove(from: URL, to: URL, expected: Fingerprint) throws {
        guard from.deletingLastPathComponent() == to.deletingLastPathComponent() else { throw RenameError.unsupported }
        var coordinatorError: NSError?
        var operationError: Error?
        NSFileCoordinator().coordinate(writingItemAt: from, options: .forMoving, writingItemAt: to, options: [], error: &coordinatorError) { source, destination in
            do {
                guard try Fingerprint.read(source) == expected else { throw RenameError.changed }
                let names = try FileManager.default.contentsOfDirectory(atPath: destination.deletingLastPathComponent().path)
                guard !names.contains(where: { FilenamePolicy.key($0) == FilenamePolicy.key(destination.lastPathComponent) }) else { throw RenameError.occupied }
                guard renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 else {
                    if errno == EEXIST { throw RenameError.occupied }
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
            } catch { operationError = error }
        }
        if let coordinatorError { throw coordinatorError }
        if let operationError { throw operationError }
    }

    private func load() throws {
        guard !loaded else { return }
        batches = []
        if FileManager.default.fileExists(atPath: journalURL.path) {
            batches = try JSONDecoder().decode([RenameBatch].self, from: Data(contentsOf: journalURL))
        }
        loaded = true
    }

    private func persist() throws {
        do {
            let folder = journalURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(batches)
            try data.write(to: journalURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: journalURL.path)
            let fd = open(journalURL.path, O_RDONLY)
            guard fd >= 0 else { throw POSIXError(.EIO) }
            defer { close(fd) }
            guard fsync(fd) == 0 else { throw POSIXError(.EIO) }
            // Ask macOS to flush through the storage device's cache as well.
            if fcntl(fd, F_FULLFSYNC) != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            let dir = open(folder.path, O_RDONLY)
            if dir >= 0 { defer { close(dir) }; guard fsync(dir) == 0 else { throw POSIXError(.EIO) } }
        } catch {
            loaded = false // next operation must reload the last durable state
            throw RenameError.journal(error.localizedDescription)
        }
    }
}
