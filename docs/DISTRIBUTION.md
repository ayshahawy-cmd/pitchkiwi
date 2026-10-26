# Release and distribution guide

GitHub Releases is the canonical download source. The website directs people there. Code, documentation, and original artwork use MIT; keep the [upstream notices](../THIRD_PARTY_NOTICES.md) with binary distributions. There is no licensing server, signup requirement, or paid feature gate.

## Community beta status

The official 0.8.4 beta app and DMG are Developer ID signed, notarized by Apple, and carry stapled tickets. Source/CI community builds default to ad-hoc signing and are not automatically notarized. It declares macOS 14+ and targets Apple Silicon. State this in the README, installation guide, and release notes. Bundle verification does not imply Apple validation or bit-for-bit reproducibility across toolchains.

## Build a release

1. Start from a clean checkout of the intended commit on Apple Silicon with a supported Xcode toolchain. Read `AGENTS.md` and [development setup](DEVELOPMENT.md).
2. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Packaging/Info.plist`. Example: app `0.8.4`, build `14`, prerelease tag `v0.8.4-beta.1`.
3. Update `CHANGELOG.md`, `docs/releases/<tag>.md`, and `docs/RELEASE_VERIFICATION.md`. Separate automated results from pending manual checks.
4. Run:

   ```bash
   make bootstrap
   swift build
   swift test
   make release
   cd .build
   shasum -a 256 -c PitchKiwi-macOS.dmg.sha256
   shasum -a 256 -c PitchKiwi-macOS.zip.sha256
   ```

`make release` ensures the checksum-pinned English model exists, builds the app, embeds notices and privacy metadata, signs ad-hoc by default (or with the configured Developer ID), verifies the bundle, and creates:

- `.build/PitchKiwi-macOS.dmg`: compressed, read-only disk image with the app, Applications shortcut, and installation guide.
- `.build/PitchKiwi-macOS.dmg.sha256`: portable DMG checksum.
- `.build/PitchKiwi-macOS.zip`: alternative app archive with default model and licenses.
- `.build/PitchKiwi-macOS.zip.sha256`: portable checksum using the ZIP basename.

Run `make check-dmg` to verify the image, mount it read-only, validate its complete app and Applications shortcut, and detach it. For the ZIP, extract into a temporary directory and run `./scripts/check-release.sh /path/to/extracted/PitchKiwi.app` against the distributable. Verify that the executable loads the bundled framework rather than a developer path. Never include credentials, recordings, user settings/history, or the source checkout in the ZIP.

## Manual verification matrix

Record platform and result for each check. Pending is not a pass.

| Area | Check |
| --- | --- |
| Installation | Download, checksum, mount DMG, drag to Applications, eject, normal first launch |
| Permissions | Deny/grant Microphone and Accessibility; recheck after updates |
| Model | First recognition, offline use, missing/corrupt model recovery |
| Capture | Hold/release, hands-free, Escape, device loss, silence |
| Insertion | TextEdit, browser textarea, Terminal, one Electron editor with synthetic text |
| Submission | Terminal text does not execute; chat text does not submit |
| Clipboard | Rich text/image/text restoration and external clipboard changes |
| Context | Off by default, bounded opt-in hints, secure fields |
| Storage | History Never, retention change, clear history and counters |
| Accessibility | Keyboard, VoiceOver, Reduce Motion, appearances |

Unit tests cover selected components. Cross-app behavior and instrumented zero-network/disk-canary tests require separate evidence. Use synthetic content; do not capture the user's live microphone as a release test without a specific reason and consent.

## Publish on GitHub

Commit reviewed changes, push `main`, and wait for CI. Create an annotated tag on the tested commit and publish the DMG, ZIP, and both checksum files. Example with GitHub CLI:

```bash
git tag -a v0.8.4-beta.1 -m "PitchKiwi 0.8.4 notarized Mac beta 1"
git push origin v0.8.4-beta.1
gh release create v0.8.4-beta.1 \
  .build/PitchKiwi-macOS.dmg \
  .build/PitchKiwi-macOS.dmg.sha256 \
  .build/PitchKiwi-macOS.zip \
  .build/PitchKiwi-macOS.zip.sha256 \
  --repo ayshahawy-cmd/pitchkiwi \
  --verify-tag --prerelease --latest=false \
  --title "PitchKiwi 0.8.4 — notarized Mac download" \
  --notes-file docs/releases/v0.8.4-beta.1.md
```

GitHub excludes prereleases from `/releases/latest`; link beta users to `/releases` or the exact release tag. Verify the public page and downloads. Download published assets into a new temporary directory and verify their checksum. The website defaults to the canonical GitHub DMG; self-hosted forks can override its HTTPS destination.

CI builds a verified DMG and ZIP on pushes and PRs and exposes it as a workflow artifact. It does not publish releases automatically. SHA-pinned Actions run with `contents: read`; contributor CI needs no signing secrets.

## Repository maintenance

Maintain accurate descriptions/topics, Issues, Private Vulnerability Reporting, and a public security policy. Review every Git ref/history and tracked asset before public visibility. Models and caches stay ignored. Preserve history unless a verified leak requires deliberate cleanup and credential rotation.

## Official signing and notarization

Keep certificates in the local signing Keychain and authentication in a saved `notarytool` Keychain profile. Do not commit credentials, certificate exports, or account passwords. To produce official signed/notarized files, run:

```bash
PITCHKIWI_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
PITCHKIWI_NOTARY_PROFILE="your-saved-profile" \
make release
```

The builder signs the bundled framework first, then the app with a secure timestamp, hardened runtime, and only the microphone audio-input entitlement. The release script submits an app ZIP to Apple, requires an `Accepted` response, staples and validates the app, creates the DMG, signs/submits/staples the DMG, and verifies both with Gatekeeper before generating checksums. Both final formats include the stapled app. Uploads to Apple contain application code/resources, not local user settings or transcripts.

`PITCHKIWI_REQUIRE_NOTARIZATION=1 ./scripts/check-dmg.sh` additionally requires valid app/image tickets and Gatekeeper acceptance. A missing identity or profile is an error for a requested notarized build; the script never falls back silently. Without either environment setting, contributor builds remain ad-hoc and need no Apple account. They must not be described as notarized.

For the published 0.8.4 beta, retain the notarization submission IDs and verification results in [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md). Automatic updates and Homebrew distribution remain future work.
