# Release verification: v0.8.3-beta.1

Date: **October 25, 2026 (America/Toronto)**. App version **0.8.3**, build **13**. The release tag identifies the source revision. These are the checks performed for this community beta, not a claim of a complete security audit.

## Local environment

- Apple Silicon (`arm64`), macOS **26.3.1 (a)**, build `25D771280a`.
- Xcode **26.6**, build `17F113`.
- Apple Swift **6.3.3**; package deployment target macOS 14.
- Bundled `ggml-base.en.bin`: **147,964,211 bytes**, SHA-256 `a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002`.
- Native framework: checksum-pinned whisper.cpp `b5130`.

## Completed checks

| Check | Result |
| --- | --- |
| Existing local build, `swift test` | 40 tests, 0 failures |
| Empty-directory source setup | Copied only repository source files into a new temporary directory with no model, framework, or build cache |
| Clean `./scripts/bootstrap.sh` | Downloaded native framework and default model; both pinned SHA-256 checks passed |
| Clean `swift build` | Passed |
| Clean `swift test` | 40 tests, 0 failures |
| Clean `./scripts/package-release.sh` | Built the arm64 app and ZIP with bundled English model and legal files |
| `check-release.sh` | Bundle signature, arm64 executable, model hash, Info.plist, privacy manifest, icon, and legal-file checks passed |
| Dynamic linking | App references `@rpath/whisper.framework/Versions/Current/whisper`, with the framework bundled in Contents/Frameworks |
| Real-model inference | A synthetic macOS `say` fixture transcribed as “Please add a Settings button and update the tests.” |
| Secret scan | Gitleaks 8.30.1 scanned all 14 pre-release app commits and 13 website commits; no leaks found |
| Website JavaScript syntax | Passed |
| Website API tests | 10 tests, 0 failures |
| Website static build | Passed; 48 local links checked and MIT/direct-download copy validated |
| Website visual check | Download page reviewed at desktop and 390px mobile width; public signup-free links present, no horizontal overflow in inspected pages |
| Local download redirect | GET /api/download returned 302 to the exact beta ZIP without environment configuration |

The smoke fixture was explicitly generated for testing and is not a microphone recording. It is not included in source or release artifacts. Optional Core ML encoder lookup produced a missing-model diagnostic; recognition succeeded through the bundled standard model/Metal path. This is not a performance benchmark.

## Limits and pending manual checks

- This beta is **ad-hoc signed and unnotarized**; no Developer ID identity or Apple notarization is claimed.
- The complete first-install experience on a new macOS user account and on each supported OS version was not repeated during this preparation.
- Live microphone capture, TCC deny/regrant dialogs, TextEdit/browser/Terminal/Electron insertion, rich clipboard race scenarios, VoiceOver, and Reduce Motion need the release manual matrix in [DISTRIBUTION.md](DISTRIBUTION.md). The unit tests cover parts of these paths, not the complete interactions.
- No instrumented zero-DNS/TCP/UDP or system-wide disk-canary audit was performed. Source review found no application networking client; runtime dictation does not need a server. Build-time dependency downloads are separate.
- Imported models are format/size checked, not authenticated against a trusted catalog. History retention runs at launch and on setting changes, without a daily timer.
- macOS 14 is the declared deployment minimum, not a statement that this release was manually exercised on macOS 14 hardware.
- The documented CI workflow runs separate build/test/packaging checks on GitHub. Check its public result for the release commit; local results above do not stand in for cloud CI.

Release archives are built from the tagged source using the documented process; binary reproducibility across Xcode versions is not asserted. After publication, confirm GitHub visibility, release assets/checksum, private vulnerability reporting, and the production website deployment separately.
