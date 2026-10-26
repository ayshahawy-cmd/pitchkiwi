# Building and developing PitchKiwi

## Prerequisites

Use an Apple Silicon Mac with macOS 14+, Swift 6, Git, and Xcode 16+ or compatible Command Line Tools. Full Xcode is recommended when SDK selection fails. Release scripts use standard macOS tools: `zsh`, `curl`, `shasum`, `unzip`, `ditto`, `sips`, `iconutil`, `plutil`, `lipo`, `hdiutil`, and `codesign`. No Node.js, Python runtime, paid developer account, API key, or backend is required to build the app.

Allow at least 3 GB for dependencies and caches. Internet is required for initial pinned downloads; subsequent builds and dictation can run offline. The [website](https://github.com/ayshahawy-cmd/pitchkiwi_website) is a separate Node.js project.

```bash
xcode-select -p
xcodebuild -version
swift --version
uname -m
```

Expect `arm64`. If the active toolchain cannot find the SDK, select your Xcode installation in Xcode → Settings → Locations → Command Line Tools. Complete Xcode's first-run prompts. The package requires Swift tools 6.0; newer visual APIs are compiler/availability guarded. See [release verification](RELEASE_VERIFICATION.md) for the actual tested environment.

## A clean checkout

```bash
git clone https://github.com/ayshahawy-cmd/pitchkiwi.git
cd pitchkiwi
./scripts/bootstrap.sh
swift build
swift test
./scripts/build-app.sh
open .build/PitchKiwi.app
```

The scripts locate the checkout independently of the working directory. No source paths or environment variables need editing. Test permissions and global insertion with the generated `.app` rather than `swift run PitchKiwi`, so macOS sees its bundle identity and privacy metadata.

## Dependencies and integrity

| Component | Pin | SHA-256 |
| --- | --- | --- |
| Whisper XCFramework | `ggml-org/whisper.cpp`, `b5130`, commit `927cfce34f31707e17f2bff35c349632fb9e2c3a` | `033a43b0174e8cf9b366f72e4a428cdcf126f93ad1c87d3fa119a96bed6f231a` |
| English model | `ggerganov/whisper.cpp`, `ggml-base.en.bin` | `a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002` |

URLs and checksums live in `scripts/bootstrap.sh`. The model URL uses an upstream branch, but expected bytes are pinned by SHA-256. Changed content fails verification. Downloads are verified before installation. Bootstrap reuses the framework cache and rechecks the model. To verify a fresh framework download, move `.vendor` aside and bootstrap again. Never bypass digest failures.

`.vendor/`, `.models/`, `.build/`, and user data are ignored. The framework includes multiple slices, while the release executable targets arm64 macOS. There are no remote Swift packages, so no `Package.resolved` is generated. Keep [notices](../THIRD_PARTY_NOTICES.md) and upstream license files synchronized with dependency changes.

For an offline build, transfer the verified framework and model into `.vendor/whisper.xcframework` and `.models/ggml-base.en.bin` on an offline Mac with a preinstalled toolchain. Never transfer user transcripts/settings as build inputs.

## Commands

| Command | Result |
| --- | --- |
| `make bootstrap` | Downloads and verifies the framework and English model |
| `./scripts/bootstrap.sh --framework-only` | Installs the native framework for compilation/tests |
| `make build` | Debug package build |
| `make test` | XCTest suite with synthetic fixtures |
| `make app` | Ad-hoc signed `.build/PitchKiwi.app`; includes a model if present |
| `make release` | Bootstraps the model, builds/verifies a complete app, generates DMG + ZIP and checksums |
| `make dmg` | Creates a DMG from the already built app, with an Applications shortcut and install guide |
| `make check-dmg` | Verifies and mounts the DMG read-only, checks its app and install layout, then detaches |
| `make check-release` | Checks signature, arm64, model digest, privacy manifest, icon, and notices |
| `make smoke AUDIO=/absolute/path/to/speech.wav` | Real-model CLI transcription |
| `make clean` | Clears package build products, keeping downloaded caches |

`make app` can create a model-less developer app after framework-only bootstrap. Use `make release` for redistribution; it refuses an incomplete bundle.

## Testing

`swift test` covers gestures, state transitions, cleanup, prompt assembly, context hints, input quality gates, insertion strategy, audio levels, and JSON storage/retention. Use temporary directories and synthetic text in new tests.

The smoke CLI runs a local model against an audio file without microphone capture or cross-app insertion:

```bash
swift run pitchkiwi-smoke .models/ggml-base.en.bin /absolute/path/to/speech.wav
```

It prints the transcript to stdout; native diagnostics may go to stderr. Use synthetic audio when capturing logs. This diagnostic CLI differs from the app's content-free logging behavior. Generate a fixture with macOS `say`:

```bash
say -v Samantha -o /tmp/pitchkiwi-example.aiff "Please add a settings button and update the tests."
swift run pitchkiwi-smoke .models/ggml-base.en.bin /tmp/pitchkiwi-example.aiff
```

The generated file is an explicit developer fixture, not an app-retained recording. Remove it afterward. Installed voices vary; this is not an accuracy benchmark.

Unit tests do not exercise permission dialogs, live microphone input, every editor, clipboard races, or a clean-user install. Run the manual matrix in [distribution](DISTRIBUTION.md) when relevant and record actual results. A source review is not an instrumented zero-traffic test.

## Source map and status

| Path | Responsibility |
| --- | --- |
| `Sources/PitchKiwiApp` | UI, onboarding, app model, HUD, menu bar |
| `Sources/PitchKiwiCore` | Audio, Whisper, cleanup, insertion, hotkeys, JSON store |
| `Sources/PitchKiwiSmoke` | Diagnostic model/audio CLI |
| `Tests/PitchKiwiCoreTests` | Synthetic behavior tests |
| `Packaging/Info.plist` | Identity, version, minimum OS, microphone purpose |
| `Legal/` | Upstream license texts copied into the app |
| `.github/workflows/ci.yml` | Build, tests, complete packaging, downloadable artifacts |

Read `AGENTS.md` before implementation. Historical design documents include future SQLite, local LLMs, configurable shortcuts, and signed model catalogs. Those are not features or dependencies of this release. Current storage is JSON and cleanup is deterministic Swift. The [user guide](USER_GUIDE.md) describes shipped behavior.

## Contributions

Fork on GitHub, clone your fork, add this repository as `upstream`, create a focused branch, and run relevant checks. Open a PR against `main` with behavior, evidence, and data/permission changes. See [contributing](../CONTRIBUTING.md). Contributor builds need no signing secret or paid Apple account. Official downloads are separately signed/notarized with a maintainer identity and saved local Keychain profile; see [distribution](DISTRIBUTION.md).
