# Screenshot Renamer

A native Mac app that suggests descriptive screenshot filenames using Apple Intelligence, then lets you review, edit, rename and undo. Free and open source. No account, subscription, API key or separately installed AI model.

**Requirements:** Apple silicon, macOS 27 or later, and Apple Intelligence enabled for AI suggestions. Manual naming remains available when the model is unavailable. Apple manages its own system model downloads.

## Status

Implementation in progress. Downloadable developer previews will be published under [Releases](https://github.com/adamsardo/screenshot-renamer/releases). Public signing and notarisation are required before a general release.

## Privacy and safety

Images are processed locally. The app does not include a network client or analytics. You choose folders, inspect proposed names, and explicitly apply changes. File extensions and capture dates are preserved. Persistent local history supports undo without overwriting existing files.

## Development

Swift, SwiftUI, AppKit, Vision and Foundation Models. Xcode 27 is required. Build and release instructions will accompany the first preview.

## Licence

MIT. See [LICENSE](LICENSE).
