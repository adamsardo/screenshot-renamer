# Releasing

## Preview releases

The first preview is **ad-hoc signed, not notarised**. Code-signature verification checks bundle integrity locally; it is not an Apple trust approval. Downloaded builds can trigger Gatekeeper. Never describe these as notarised or silently remove quarantine attributes.

Tag a tested commit with `vMAJOR.MINOR.PATCH-preview.N` and push the tag. The **Publish preview release** workflow runs safety tests, builds the app, creates a DMG with an Applications shortcut, writes a SHA-256 checksum, and publishes both assets as a GitHub prerelease. It runs on GitHub's `xcode-27` Apple silicon image. Apple Intelligence inference is verified on a real supported Mac, not claimed from CI.

The **Package preview DMG** manual workflow produces downloadable Actions artifacts without publishing a release. Versions are passed through an environment variable and validated by the packaging script.

To package on a Mac:

```sh
swift test
VERSION=0.1.0-preview.1 ./scripts/package.sh
hdiutil verify dist/Screenshot-Renamer-0.1.0-preview.1-arm64.dmg
```

Use a clean tagged checkout. The app records the source revision in its Info.plist. Do not rebuild a publicly published version in place; increment the preview number. Build outputs and signing materials are ignored by Git.

## Normal public distribution

Required before a stable release:

1. An active Apple Developer account with a **Developer ID Application** signing identity and its private key available in the build Mac's keychain. An **Apple Development** identity is not a substitute.
2. A locally configured `notarytool` keychain profile. Enter credentials directly into Apple's tools; never commit or post passwords, private keys or certificates.
3. A signed, notarised and stapled build, tested after downloading on a separate supported Mac.

With those configured:

```sh
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='your-existing-notary-profile'
VERSION=0.1.0 ./scripts/package.sh
```

The script signs the app with hardened runtime and sandbox entitlements, signs the DMG, submits it to Apple's notary service, staples and validates the ticket, assesses the DMG with Gatekeeper, and generates its checksum. It stops on an unsuccessful step. This path is implemented but remains unverified until those credentials are available.

Stable tags are deliberately excluded from the automatic ad-hoc preview workflow. Upload a verified stable DMG and checksum with `gh release create` from the tested tag, or introduce a protected signing workflow once certificate management is configured. Keep signing secrets unavailable to pull requests.

## Release checklist

- Safety tests pass; exact tagged revision matches the packaged app.
- Real sandboxed import → generate → edit → rename → relaunch → undo succeeds on disposable copies.
- Byte hashes, timestamps and original names are preserved/restored.
- No private fixtures, personal paths or credentials in the source or release files.
- DMG verifies and mounts; app signature verifies; checksum matches the uploaded download.
- Requirements, AI limitations and actual signing status appear in release notes.

References: [Apple distribution signing](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/), [Apple notarisation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [GitHub runner images](https://github.com/actions/runner-images).
