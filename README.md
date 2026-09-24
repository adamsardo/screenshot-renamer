# Screenshot Renamer

Screenshot Renamer is a free Mac app that looks at your screenshots and suggests names you can actually search for later. It uses Apple Intelligence on your Mac, you approve every name before anything changes, and a local history lets you undo.

[Download a DMG from Releases](https://github.com/adamsardo/screenshot-renamer/releases) · [Build from source](#build-from-source) · [Privacy and safety](docs/PRIVACY.md)

## What you need

- An Apple silicon Mac on macOS 27 or later.
- Apple Intelligence turned on, with its system model available. Apple decides which languages and regions get it.
- You don't need Xcode to run the downloaded app.

There's no subscription, in-app purchase, API key, model server or separate AI model to install. Apple handles downloading its own model. If Apple Intelligence isn't available, you can still type descriptions yourself.

## Install

1. Download the `.dmg` from [Releases](https://github.com/adamsardo/screenshot-renamer/releases).
2. Open it and drag Screenshot Renamer into Applications.
3. Launch the app and pick some images or a folder.

This first release is a developer preview. It's ad-hoc signed and not notarised, so macOS may refuse to open it. If you trust this repo and the release, try opening the app once, then go to System Settings → Privacy & Security and click **Open Anyway** for this app. Please don't turn off Gatekeeper for your whole system. A properly verified release needs a Developer ID certificate and Apple notarisation, and neither is set up yet. [Release details](docs/RELEASING.md).

## How to use it

1. Click **Add Images** or **Add Folder**, or drag files and folders onto the window. PNG, JPEG and HEIC all work. Adding a folder only picks up images at the top level, not in subfolders. If you use CleanShot, the empty screen has a filter for its files.
2. Click **Generate Names**. The app describes your images one at a time, entirely on your Mac. If you cancel partway, you keep the suggestions it already made.
3. Click a row to preview the image and edit its description. The checkboxes decide which images get renamed; selecting a row doesn't. Your edits stick unless you click **Regenerate Name** on that image.
4. Check each full filename, then click **Rename**. If you added individual files rather than a folder, you may need to click **Allow Folder Access** first.
5. To undo, open **History** or press **⌘Z**. **⇧⌘Z** redoes the last batch you undid, if it's still possible. History and folder permissions survive app restarts.

Each filename is the description plus the capture date:

```text
Sonos speaker pricing — 2026-09-06.png
```

The app takes the date from the screenshot's filename when it recognises the format, or from the image metadata. If neither has one, it falls back to the file's creation date and labels it clearly. The model never picks the date. Your original file extension stays the same. If two images would end up with the same name, you'll see a numbered suffix before you rename anything.

## What's in the preview

- A native SwiftUI window with image preview, editable suggestions and keyboard shortcuts.
- Images go straight to Foundation Models, with Apple Vision text recognition for extra context.
- Everything runs locally. The app has no network entitlements and no telemetry.
- Renames never overwrite existing files. The app checks each file's fingerprint before renaming and keeps recovery records on disk.
- Batch history that survives restarts, undo and redo, collision handling, and a report when only part of a batch succeeds.
- A packaged Apple silicon app in a drag-to-Applications DMG.

AI suggestions can be vague, wrong, or include details you'd rather keep out of a filename, so read them before you rename. This preview is for hands-on use; it doesn't watch folders or rename things in the background. [Verification and limitations](docs/VERIFICATION.md).

## Build from source

You'll need Xcode 27 with the macOS 27 SDK. Open `Package.swift` in Xcode, or build from the terminal:

```sh
git clone https://github.com/adamsardo/screenshot-renamer.git
cd screenshot-renamer
# Set DEVELOPER_DIR only if your desired Xcode is not selected globally.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
./scripts/build.sh
```

The app ends up in `dist/Screenshot Renamer.app`, ad-hoc signed by default. To test sandbox behaviour, run the packaged app, because `swift run` doesn't run inside the sandbox.

To make a local preview DMG:

```sh
VERSION=0.1.0-preview.1 ./scripts/package.sh
```

There are no third-party Swift packages or runtime dependencies. The project uses a Swift package plus explicit bundling scripts, so Xcode users and command-line users build from the same definition.

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md), the [architecture notes](docs/ARCHITECTURE.md) and the [release instructions](docs/RELEASING.md). Please test with made-up or throwaway images, and keep your personal screenshots out of issues and pull requests.

## References and licence

The code is original and [MIT licensed](LICENSE). Research into workflow and safety drew on [StoneHub/screenshot-renamer](https://github.com/StoneHub/screenshot-renamer), [svetzal/image-namer](https://github.com/svetzal/image-namer) and [ma08/omnishot](https://github.com/ma08/omnishot), but none of their code is bundled. TidyShot's behaviour was also used as a reference. Its source has no licence, so none of it was copied.
