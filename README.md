# Screenshot Renamer

**Turn screenshots into filenames you can find.** A free, native Mac app that uses on-device Apple Intelligence to suggest names, lets you review and edit them, and keeps a local history for undo.

[Download a DMG from Releases](https://github.com/adamsardo/screenshot-renamer/releases) · [Build from source](#build-from-source) · [Privacy and safety](docs/PRIVACY.md)

## Requirements

- An Apple silicon Mac running **macOS 27 or later**.
- Apple Intelligence enabled and its system model available for AI suggestions. Language and region availability are managed by Apple.
- Xcode is **not** needed to run a downloaded app.

No subscription, in-app purchases, API key, external model server or separately installed AI model. Apple manages downloads of its own system model. Manual descriptions work when Apple Intelligence is unavailable.

## Install

1. Open [Releases](https://github.com/adamsardo/screenshot-renamer/releases) and download the `.dmg` asset.
2. Open it and drag **Screenshot Renamer** into **Applications**.
3. Launch the app and choose images or a folder.

**The first release is a developer preview, ad-hoc signed and not notarised.** macOS may block a downloaded copy. If you trust this repository and the release, use the per-app **Open Anyway** option in System Settings → Privacy & Security after attempting to open it. Do not disable Gatekeeper globally. A normally verified public release requires a Developer ID certificate and Apple notarisation; that setup is still outstanding. [Release details](docs/RELEASING.md).

## Use

1. **Add Images** or **Add Folder**, or drop files/folders into the window. PNG, JPEG and HEIC are supported. Folder imports are nonrecursive; an optional CleanShot filter is available on the empty screen.
2. Choose **Generate Names**. Descriptions are generated one at a time on your Mac. You can cancel and keep completed suggestions.
3. Select a row to preview its image and edit the description. Checkboxes control which images are included; selecting rows is separate. Manual edits are preserved unless you choose **Regenerate Name** for that image.
4. Check the complete proposed filename, then choose **Rename**. File-only imports may require **Allow Folder Access** first.
5. Use **History** or **⌘Z** to undo. History and folder permissions persist across app restarts. **⇧⌘Z** redoes the last undone batch where valid.

Names use **description + capture date**, for example:

```text
Sonos speaker pricing — 2026-09-06.png
```

The date comes from a recognised capture filename, image metadata, or a clearly labelled file-creation-date fallback. The model never supplies the date. The original extension is preserved. Duplicate names receive a visible numbered suffix before you apply the batch.

## What the preview includes

- Native SwiftUI window, image preview, editable suggestions and keyboard commands.
- Direct Foundation Models image input with Apple Vision text recognition for context.
- Local processing, without network entitlements or telemetry.
- Exclusive no-overwrite renames, source fingerprint checks and durable recovery records.
- Persistent batch history, undo/redo, collision handling and partial-failure reporting.
- A packaged Apple silicon `.app` in a drag-to-Applications DMG.

AI suggestions can be vague or inaccurate and may include details you prefer to keep out of filenames. Review them. This preview is for interactive use; it is not an unattended folder watcher. [Verification and limitations](docs/VERIFICATION.md).

## Build from source

Install Xcode 27 with the macOS 27 SDK. Open `Package.swift` in Xcode, or build from a terminal:

```sh
git clone https://github.com/adamsardo/screenshot-renamer.git
cd screenshot-renamer
# Set DEVELOPER_DIR only if your desired Xcode is not selected globally.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
./scripts/build.sh
```

The app is written to `dist/Screenshot Renamer.app`. The script uses ad-hoc signing by default. Run the packaged app when testing sandbox behaviour; `swift run` does not reproduce the sandboxed app environment.

To create a local preview DMG:

```sh
VERSION=0.1.0-preview.1 ./scripts/package.sh
```

There are no third-party Swift package or runtime dependencies. The project uses a Swift package and explicit app-bundling scripts so both Xcode and command-line contributors can use the same build definition.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [architecture](docs/ARCHITECTURE.md) and [release instructions](docs/RELEASING.md). Please use synthetic or disposable test images and keep personal screenshots out of issues and pull requests.

## References and licence

Original implementation under the [MIT licence](LICENSE). Workflow and safety research included [StoneHub/screenshot-renamer](https://github.com/StoneHub/screenshot-renamer), [svetzal/image-namer](https://github.com/svetzal/image-namer) and [ma08/omnishot](https://github.com/ma08/omnishot). No source code from these projects is bundled. TidyShot was inspected as a behavioural reference; its unlicensed source was not copied.
