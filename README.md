# VibeFlow

> A private, local-first voice-to-text app for developers on macOS.

VibeFlow lets you hold **Option + Space**, speak, and release to insert polished text into the app you were using. Microphone audio stays in memory, transcription runs through `whisper.cpp` on your Mac, and no account or server is involved.

This is an original open-source implementation inspired by the fluid interaction model of modern dictation tools. It does not use Wispr Flow source code, private APIs, branding, copy, or visual assets.

## What works today

- Native SwiftUI/AppKit app and menu-bar control—no Electron.
- Global push-to-talk with a compact floating HUD.
- In-memory microphone capture; raw audio is never written to disk.
- Local Whisper transcription with Metal acceleration.
- Accessibility-first insertion into editors, terminals, browsers, and chat fields.
- Clipboard fallback that restores the previous clipboard when possible.
- Conservative cleanup for filler, repetition, punctuation, and casing.
- Developer speech such as `dot env`, `dash dash force`, casing commands, and Markdown punctuation.
- Personal dictionary and exact-match voice snippets.
- Scratchpad, local usage metrics, and configurable transcript retention.
- History off and nearby-context reading off by default.
- Secure-field refusal and a hard rule against synthesizing Return/Enter.

## Quick start

Requirements: macOS 14 or newer, Xcode command-line tools, and an Apple Silicon Mac.

```bash
git clone <your-repository-url>
cd vibeflow
./scripts/bootstrap.sh
swift test
./scripts/build-app.sh
open .build/VibeFlow.app
```

The bootstrap script downloads a checksum-pinned official `whisper.cpp` XCFramework and the `ggml-base.en` model. They are kept in ignored local directories and copied into the final app bundle. The build script produces an ad-hoc-signed app at `.build/VibeFlow.app`.

On first use, macOS will ask for:

1. **Microphone** — required to hear push-to-talk dictation.
2. **Accessibility** — required for the global shortcut and inserting text into other apps.

The app remains useful without Accessibility permission: completed text stays available to copy manually.

## Use it

1. Put the cursor in any normal text field.
2. Hold **Option + Space**.
3. Speak naturally.
4. Release the keys and wait for local transcription.

VibeFlow inserts text but never submits a form or executes a terminal command. Press **Escape** while listening to cancel. The first transcription can be slower while Metal compiles its local kernels; later runs are faster.

## Privacy model

The default workflow has no network path:

```text
Microphone → memory-only PCM → local Whisper → local cleanup → focused text field
```

- The application binary contains no analytics, account, sync, transcription API, or cloud rewrite integration.
- Raw audio is discarded after transcription or cancellation.
- Transcript history defaults to **Never**.
- Dictionary, snippets, settings, and aggregate counters live in `~/Library/Application Support/VibeFlow/vibeflow.json` with owner-only permissions.
- Importing a model copies only the model selected by the user.
- Network access is used by the developer bootstrap script only to fetch pinned build dependencies.

See [Security](docs/SECURITY.md) for the threat model and [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Architecture

| Layer | Implementation |
| --- | --- |
| UI | Swift 6, SwiftUI, focused AppKit bridges |
| Capture | AVFoundation / AVAudioEngine, converted to 16 kHz mono PCM |
| Speech | `whisper.cpp` v1.9.4-compatible XCFramework, Metal enabled |
| Cleanup | Deterministic Swift pipeline; no generative rewrite by default |
| Insertion | macOS Accessibility APIs, then guarded paste fallback |
| Storage | Codable JSON, atomic writes, file protection, mode `0600` |
| Packaging | Swift Package Manager plus a reproducible `.app` bundle script |
| Tests | XCTest plus a real-model smoke-test executable |

The core engine is protocol-driven so capture, transcription, refinement, and insertion can be tested independently. Read [Architecture](docs/ARCHITECTURE.md), [Product spec](docs/PRODUCT_SPEC.md), [Prompt architecture](docs/PROMPT_ARCHITECTURE.md), and [Design system](docs/DESIGN_SYSTEM.md) for the full rationale.

## Developer commands

```bash
make bootstrap   # download and verify local framework + default model
make build       # debug build
make test        # unit tests
make app         # release build at .build/VibeFlow.app
```

To test the actual model against an audio file:

```bash
swift run vibeflow-smoke .models/ggml-base.en.bin /path/to/speech.wav
```

The smoke executable accepts AVFoundation-readable audio and prints the locally transcribed/refined result.

## Repository map

```text
Sources/VibeFlowApp/       native app, screens, HUD, orchestration
Sources/VibeFlowCore/      audio, Whisper, refinement, insertion, storage
Sources/VibeFlowSmoke/     real-model command-line smoke test
Tests/                     state, privacy, refinement, and audio tests
Assets/                    original project artwork
Packaging/                 macOS bundle metadata
scripts/                   pinned bootstrap and app packaging
docs/                      product, architecture, security, and UX specs
```

## Current scope and roadmap

The working MVP is English-first and targets Apple Silicon. It provides non-streaming push-to-talk, deterministic cleanup, and local JSON persistence. Planned follow-ups include configurable hotkeys, multilingual model selection, streaming partials, richer transforms through an optional local model, encrypted export/import, release notarization, and deeper app compatibility testing.

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Preserve [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) in redistributed builds.

## Naming and license

`VibeFlow` is a working project name; perform a trademark and repository-name check before publishing a release. The project is licensed under [MIT](LICENSE).
