# Architecture

The app is a Swift package with a native SwiftUI executable and a separate testable core. `scripts/build.sh` wraps the executable in a sandboxed `.app`. This replaces the preliminary plan's separate Xcode app target with one build definition that Xcode can also open.

## Components

- **Workspace**: main-actor observable UI state, imports, selection, progress and explicit user actions.
- **FolderAccess**: user-selected read/write scope, persisted security-scoped bookmarks. A file-only grant does not imply access to new sibling filenames.
- **ImageServices**: local image validation, bounded thumbnails, capture-date extraction and file-provider placeholder checks. PNG/JPEG/HEIC, 50 MB and 100 million pixel limits. Import processing happens off the main actor.
- **AppleNamingService**: an actor using Vision OCR and a fresh Foundation Models session per image. Image content and OCR are untrusted data. Structured output contains a title only. Default Apple safety behaviour remains enabled.
- **FilenamePolicy**: date priority, filename sanitation, byte limits, case/Unicode comparisons and previewed collision suffixes.
- **RenameEngine**: serial actor, SHA-256 plus filesystem identity/mtime checks, NSFileCoordinator, Darwin `RENAME_EXCL`, and atomic journal writes flushed before and after each mutation.

## File-operation contract

Generate never renames a file. Apply uses the exact reviewed destination. The engine checks source identity and content immediately before each move. A new collision is a failure, not an automatically changed filename. Extension changes and moves between folders are rejected. Rename cycles and case-only changes are not staged through temporary names in this version.

A batch is a sequence of individual operations, not an atomic multi-file transaction. Each intent is saved before a move; each result is saved afterwards. If the app stops between those writes, recovery compares the original and destination file fingerprints. It does not assume an arbitrary destination file belongs to the app. Ambiguous or inaccessible entries require folder access/review.

Undo/redo uses the same checks. Existing files are never overwritten. History stores paths and fingerprints in the sandbox's Application Support directory with restricted permissions. If a journal cannot be read, mutations fail closed; it is not silently replaced. If persistence fails, subsequent operations reload durable state.

## Limits

NSFileCoordinator coordinates with cooperating apps; no filesystem tool can promise immunity from all simultaneous interference by another process. Externally moved, edited, locked or unavailable files can require manual review. File-provider placeholders are skipped, and no batch-wide download is requested. A file-provider operation already in progress can still delay a filesystem call.

Import and generation cancellation are cooperative. The app stops at the next check, and a running Apple model request may take time to finish. Rename batches are short, serial operations; the UI disables cancellation during apply/undo and preserves durable recovery for interrupted runs.

The list is session-local; history persists. Titles and OCR text are not stored separately. There is no cloud AI fallback, telemetry, background watcher, recursive folder import or automatic update service.
