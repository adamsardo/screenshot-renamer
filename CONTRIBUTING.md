# Contributing

Use Xcode 27 and macOS 27 on Apple silicon. Open Package.swift in Xcode or run `swift test` and `./scripts/build.sh`. No third-party dependency installation is needed.

Use small focused changes. Include a regression test when changing file-operation safety. Test the packaged app for permissions and model access. Do not use valuable originals as rename fixtures. Never commit personal screenshots, OCR logs, signing keys or local histories.

Before a pull request, run `swift test`, build the app, and describe the user-visible change and the checks performed. UI changes should be checked in the actual native window. Model tests should report refusals separately from successful but inaccurate suggestions; producing text is not proof of naming quality.

Security reports should not include private user data. For a vulnerability, use GitHub's private vulnerability reporting when available, or contact the maintainer privately before posting exploit details.
