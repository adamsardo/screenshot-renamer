# Verification — 0.1.0-preview.1

Checked on 24 September 2026 using an Apple silicon Mac, macOS 27.0 and Xcode 27. Personal image fixtures and their filenames are excluded from the repository.

## Observed

- **15 Swift tests pass** locally: capture dates and safe names; rename/undo/redo after reloading history; late conflicts; changed sources and partial failure; undo conflicts; symlink rejection; duplicate destinations and extension changes; crash recovery before/after a move; ambiguous recovery; Unicode/case conflicts; corrupt-history fail-closed behaviour; locked files; metadata preservation.
- GitHub's `xcode-27` runner successfully built the packaged app and ran all **15 tests**. Main-branch pushes and preview releases rerun the suite; check the workflow for the exact commit being downloaded.
- The packaged **sandboxed app** imported 20 disposable copies of real screenshots through the native folder picker.
- Direct on-device image-plus-OCR naming produced suggestions for **20/20** images in that run. No external AI endpoint or CLI was used.
- The native inspector displayed an image and allowed a manual title edit before Apply.
- Applying the reviewed batch renamed **20/20** copies. SHA-256 checks confirmed every image's bytes were unchanged. Original source screenshots were untouched.
- After quitting and relaunching, the saved history and folder access supported **undo of all 20 images**, restoring original filenames. Content hashes, inode identities, creation dates and modification dates were preserved.
- A second native UI run loaded **520 disposable image fixtures**. The completed list was visible at the first post-click inspection, about 1.9 seconds later. Editing remained responsive.
- Generation cancellation returned to the review state at the first post-click inspection, about 1.5 seconds later in that run. Completed suggestions and a manually edited title were retained. These are UI observations on one Mac, not performance guarantees.
- The actual dark-mode review window, image inspector, filename editor, progress state and history sheet were inspected.
- Packaged app signatures verify locally with sandbox and hardened-runtime entitlements. **Ad-hoc signature verification is not notarisation.**

- The DMG checksum verification passed. It mounted with the app, Applications shortcut, licence and installation note.
- The app was launched directly from that mounted DMG. Its source revision matched the build commit; persistent History successfully redid and undid the same 20-file batch. All 20 original filenames and image hashes were restored again.
- Gatekeeper assessment **rejected** the ad-hoc app, as expected. No security setting was disabled or quarantine attribute removed. This is why the public download is clearly marked as an unnotarised developer preview.

## Quality findings

Returning a suggestion is not the same as getting the name right. The 20-image run included useful application/product titles, broad descriptions, an overlong title, and wording that still needed editing. A previously misidentified image improved to a broad drawing-settings description with OCR context but still omitted the visible app name.

The preliminary eight-image, image-only check had six responses and two refusals. The later image-plus-OCR check returned names for both previously refused examples using unchanged default Apple guardrails. This is a small exploratory comparison, not a controlled benchmark or a guarantee against future refusals.

The proposed 80% useful-without-editing quality target has **not** been established by a blinded human assessment. Naming is labelled experimental. Preview and manual editing are part of the intended workflow.

## Still unverified

- Developer ID signing, Apple notarisation and first installation on a separate Mac.
- A formal VoiceOver audit, systematic light-mode/reduced-motion checks and every Finder drag/drop variant.
- Every cloud provider's offline, download, cancellation and permissions behaviour.
- Power-loss durability on every filesystem. Recovery tests simulate interrupted journals in disposable folders; they do not physically interrupt disk power.
- A statistically useful accuracy evaluation across different users, languages and screenshot types.

The preview is suitable for evaluating the interactive workflow on disposable copies. It is not labelled a finished, notarised general release.
