# Build plan

> **Document status:** This design document includes future goals and acceptance criteria, not a statement that every item ships. The current beta uses JSON storage, deterministic cleanup, a fixed Fn shortcut, and local model import. Read [USER_GUIDE.md](USER_GUIDE.md) for shipped behavior and limitations, and [RELEASE_VERIFICATION.md](RELEASE_VERIFICATION.md) for actual test evidence.

## Working method

Build vertical slices with acceptance gates. Each phase ends with a compilable app, automated tests, a manual demonstration, and updated documentation. Do not hide incomplete privacy or permission behavior behind mock UI.

## Phase 0 — repository and decisions

Deliverables:

- Finalize the working product name or record it as temporary.
- Create the Xcode project, production/test/UI-test targets, formatter/linter config, and CI.
- Add ADR template and ADRs for native UI, local inference, storage, and distribution.
- Pin toolchain and dependency versions.
- Add third-party notice generation and secret/license scans.

Gate:

- Clean checkout builds and tests from documented commands.
- CI runs without signing secrets.
- No model weights or user artifacts are tracked.

## Phase 1 — native shell and state machine

Deliverables:

- Menu-bar app and main SwiftUI navigation.
- Original design tokens and HUD window.
- Permission status surfaces.
- Configurable shortcut abstraction using a fake provider first.
- Actor-backed dictation state machine with fake audio/transcription/insertion services.

Gate:

- All allowed/invalid state transitions tested.
- HUD is visible, nonactivating, VoiceOver-labeled, and adapts to light/dark/Reduce Motion.
- A fake dictation round trip reaches a local in-app field.

## Phase 2 — audio capture

Deliverables:

- Microphone selection and AVAudioEngine capture.
- 16 kHz mono conversion and in-memory bounded ring buffer.
- Level meter, duration warning, cancellation, device-change handling.
- Synthetic and bundled public-domain fixture tests.

Gate:

- No audio file is created in release configuration.
- Denied/revoked/busy/device-removed states recover cleanly.
- Capture begins within the product budget on reference hardware.

## Phase 3 — local Whisper

Deliverables:

- Pinned `whisper.cpp` integration with Metal.
- Model catalog, download/import, SHA-256 verification, install/delete, warm-up.
- `WhisperEngineActor` and cancellation.
- Benchmark harness and first published results.

Gate:

- Fixture transcribes with networking disabled.
- Corrupt/wrong/partial models are rejected.
- Model deletion never targets outside the model directory.
- Memory pressure and inference failure recover without losing UI control.

## Phase 4 — global shortcut and insertion

Deliverables:

- Real global push-to-talk and hands-free shortcuts with conflict detection.
- Accessibility target capture and selected-text replacement.
- Guarded clipboard lease fallback.
- Paste Last Transcript and undo receipt.
- Terminal safety mode.

Gate:

- Manual matrix passes in TextEdit, Safari/Chrome text area, Terminal, and one of VS Code/Cursor/Windsurf.
- Clipboard representations survive success, failure, cancellation, and external race.
- The app never sends Return or submits content.

## Phase 5 — deterministic intelligence

Deliverables:

- Pure cleanup pipeline with typed changes.
- Dictionary/corrections and snippets.
- Spoken punctuation and developer command grammar.
- Identifier/file candidate extraction behind opt-in context.
- App category and style rules.

Gate:

- Synthetic evaluation corpus meets protected-span, negation, and false-trigger requirements.
- Context-off mode reads no content.
- Secure fields and denied apps yield empty context.

## Phase 6 — storage, history, and Insights

Deliverables:

- GRDB schema and migrations.
- History-off default and retention service.
- Content-free daily metrics.
- Home history and original Insights screen.
- Clear-category and Delete All flows.

Gate:

- History-off disk scan finds no canary transcript/audio.
- Retention boundary/migration/corruption tests pass.
- Destructive UI names affected data and requires confirmation.

## Phase 7 — transforms and optional local LLM

Deliverables:

- Selected-text capture and diff UI.
- Polish and Prompt Builder.
- Optional `llama.cpp`-backed local rewrite adapter and model import.
- Prompt schema, preservation manifest, validator, timeout, cancellation, deterministic fallback.
- Custom transforms using bounded instructions.

Gate:

- Full prompt evaluation corpus passes hard safety thresholds.
- Adversarial source text cannot alter the immutable contract.
- Invalid/slow/oversized output is never inserted.
- The feature works with no network entitlement.

## Phase 8 — polish and public beta

Deliverables:

- Performance, energy, memory, and Accessibility audits.
- Hardened runtime, Developer ID signing, notarization, artifact checksums.
- DMG/ZIP release workflow and optional Homebrew Cask draft.
- Screenshots using synthetic text only.
- Complete README, contribution docs, changelog, privacy statement, threat model, notices.

Gate:

- Clean-machine install and onboarding passes.
- Offline end-to-end and no-persistence tests pass.
- Permissions can be denied/revoked without trapping the user.
- Release artifact and checksum are reproducible and documented.

## Suggested milestones

- `0.1.0`: shell + fake engine demo.
- `0.2.0`: real local transcription in-app.
- `0.3.0`: global dictation and safe insertion.
- `0.4.0`: developer cleanup, dictionary, snippets.
- `0.5.0`: history/Insights and privacy hardening.
- `0.6.0`: optional local transforms.
- `0.9.0`: notarized public beta.
- `1.0.0`: acceptance matrix complete.

Versions indicate capability, not dates. Do not compress gates to meet a calendar target.

## Manual smoke script per release

1. Launch from a clean user account.
2. Read privacy screen and deny Microphone; confirm recovery.
3. Grant Microphone and import a verified model from disk.
4. Disable networking.
5. Dictate into the in-app test field.
6. Grant Accessibility and dictate into TextEdit.
7. Dictate identifiers and a filename into the supported IDE.
8. Dictate a command into Terminal and confirm it is not executed.
9. Exercise Escape, target switch, failed paste, and Paste Last Transcript.
10. Set history to Never, dictate canary text, quit, relaunch, and run persistence scan.
11. Enable history, verify local entry and Insights counters, then delete it.
12. Revoke permissions while running and confirm graceful fallback.

