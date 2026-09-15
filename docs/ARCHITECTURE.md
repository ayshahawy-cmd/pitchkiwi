# Architecture

## 1. Decision summary

PitchKiwi should be a native menu-bar macOS application with a conventional settings window and a borderless floating HUD. Swift owns the orchestration and privacy boundary. `whisper.cpp` is embedded as a pinned native library for local speech recognition. Optional local rewriting is isolated behind a second engine adapter and is never part of the required transcription path.

Wispr Flow's exact private stack is not publicly established. This architecture reproduces useful product behavior with public macOS APIs and open-source local inference; it does not claim to duplicate Wispr's implementation.

## 2. Runtime data flow

```text
Global shortcut
      |
      v
DictationCoordinator (actor + state machine)
      |
      +--> PermissionService
      +--> AudioCaptureService --> in-memory PCM ring buffer
      +--> ContextService ------> bounded ephemeral ContextEnvelope
      |
      v
WhisperTranscriber --> RawTranscript
      |
      v
DeterministicRefiner
  punctuation -> repetitions -> corrections -> snippets -> developer tokens
      |
      +--> optional LocalRewriteEngine --> validated rewrite or fallback
      |
      v
InsertionService --> AX replacement OR guarded clipboard lease + Cmd-V
      |
      +--> ephemeral LastResult cache
      +--> optional TranscriptRepository
      +--> content-free MetricsRepository
```

The context envelope and audio buffer are job-scoped values. They must be released when the job completes, cancels, or errors.

## 3. Module boundaries

Suggested source shape:

```text
PitchKiwi/
├── App/
│   ├── PitchKiwiApp.swift
│   ├── AppDelegate.swift
│   └── AppEnvironment.swift
├── Core/
│   ├── DictationCoordinator.swift
│   ├── DictationState.swift
│   ├── DictationJob.swift
│   └── DomainModels.swift
├── Audio/
│   ├── AudioCapturing.swift
│   └── AVAudioCaptureService.swift
├── Transcription/
│   ├── SpeechTranscribing.swift
│   ├── WhisperCppTranscriber.swift
│   └── ModelManager.swift
├── Refinement/
│   ├── TextRefining.swift
│   ├── DeterministicRefiner.swift
│   ├── DeveloperTokenFormatter.swift
│   ├── DictionaryMatcher.swift
│   ├── SnippetExpander.swift
│   └── LocalRewriteEngine.swift
├── Context/
│   ├── ContextReading.swift
│   ├── AccessibilityContextReader.swift
│   └── SensitiveTargetPolicy.swift
├── Insertion/
│   ├── TextInserting.swift
│   ├── AccessibilityInserter.swift
│   ├── ClipboardInserter.swift
│   └── ClipboardLease.swift
├── Storage/
│   ├── AppDatabase.swift
│   ├── TranscriptRepository.swift
│   ├── PreferencesRepository.swift
│   └── RetentionService.swift
├── Permissions/
├── Hotkeys/
├── Features/
│   ├── HUD/
│   ├── Home/
│   ├── Dictionary/
│   ├── Snippets/
│   ├── Styles/
│   ├── Transforms/
│   ├── Insights/
│   └── Settings/
└── Resources/
```

Keep UI features dependent on protocols and domain models, not concrete infrastructure.

## 4. Core protocols

```swift
protocol AudioCapturing: Sendable {
    func start(configuration: AudioConfiguration) async throws
    func stop() async throws -> AudioBuffer
    func cancel() async
}

protocol SpeechTranscribing: Sendable {
    func warmUp(model: ModelID) async throws
    func transcribe(_ audio: AudioBuffer, hints: [String]) async throws -> RawTranscript
    func cancelCurrentTranscription() async
}

protocol TextRefining: Sendable {
    func refine(_ input: RefinementInput) async throws -> RefinementResult
}

protocol ContextReading: Sendable {
    func snapshot(policy: ContextPolicy) async -> ContextEnvelope
}

protocol TextInserting: Sendable {
    func captureTarget() async -> InsertionTarget
    func insert(_ text: String, into target: InsertionTarget) async throws -> InsertionReceipt
    func undo(_ receipt: InsertionReceipt) async throws
}
```

Use value types for job inputs/outputs. If a value contains text or audio, avoid `CustomStringConvertible` and ensure log interpolation is private/redacted.

## 5. State machine

`DictationCoordinator` is an actor. Only it owns the active job identifier.

Allowed transitions:

```text
idle -> listening
listening -> transcribing | cancelling | error
transcribing -> refining | cancelling | error
refining -> inserting | result | cancelling | error
inserting -> idle | result | error
cancelling -> idle
error -> idle | listening
result -> idle | inserting
```

Every asynchronous result carries its job ID. Results for an old/cancelled job are ignored. The coordinator publishes a small, `@MainActor` view state without exposing transcript/audio values until the result screen needs them.

## 6. Audio pipeline

- `AVAudioEngine` input node.
- Convert to 16,000 Hz, mono, Float32 PCM.
- Bounded ring buffer sized for the maximum dictation.
- Optional energy meter for the waveform; do not implement always-on VAD in v1.
- Snapshot the insertion target at start, then verify target identity before insertion.
- For dictations over 20 seconds, phase 2 may perform overlapping background segments and a final reconciliation pass. Do not ship unstable partial-text merging in the first slice.

Audio lifecycle is memory only. Diagnostic audio capture must require a separate debug build flag and an explicit per-capture action; release builds exclude it.

## 7. Whisper integration

Use the maintained `ggml-org/whisper.cpp` source/package or a repository-built XCFramework pinned by revision and checksum. Enable Metal on Apple Silicon. Keep the C API behind a narrow Swift actor to serialize model access and make cancellation explicit.

Initial model tiers, subject to benchmark validation:

| Tier | Candidate | Purpose |
| --- | --- | --- |
| Fast | quantized `base.en` | 8 GB Macs, lowest latency |
| Balanced | quantized `small.en` | default recommendation for 16 GB English use |
| Accurate | quantized `medium.en` or compatible turbo variant | high-memory Macs, slower finish |
| Multilingual | matching multilingual model | opt-in non-English use |

Never hard-code marketing claims. The model catalog is a signed-in-repo JSON resource with URL, byte size, digest, language, and minimum recommended memory. Imported models remain possible for a fully offline installation.

## 8. Cleanup architecture

The deterministic chain consists of pure transforms. Each produces text plus a typed change list:

1. Unicode normalization.
2. Whitespace and punctuation normalization.
3. Conservative filler/repetition removal.
4. Spoken punctuation/format commands.
5. Correction pairs using longest-match-first token boundaries.
6. Exact-case dictionary restoration.
7. Snippet expansion under explicit trigger rules.
8. Developer token and filename resolution.
9. Output safety/preservation validation.

The optional local rewrite engine receives the deterministic output, never raw audio. It returns structured data and is accepted only if preservation checks pass.

## 9. Context collection

Context levels:

- `off` (default): target bundle identifier and focused element role only.
- `focusedField`: up to 1,000 characters before and after the cursor from a nonsecure focused text control.
- `developerVisible`: `focusedField` plus visible Accessibility labels for editor tabs/file tree within strict time and item limits.

No level captures screenshots, browser history, the pasteboard, hidden windows, full files, or unrelated conversations. The sensitive-target policy blocks secure roles and user-configured bundle identifiers. Collection times out rather than delaying dictation.

## 10. Text insertion

Preferred strategy order:

1. Accessibility selected-text replacement when the target exposes a writable text range.
2. Guarded pasteboard lease followed by Command-V.
3. In-app result card; do not force insertion.

`ClipboardLease` snapshots all pasteboard items and change count, writes the temporary text, pastes, then restores only if no third party changed the clipboard after the temporary write. If another app changed it, preserve the newer clipboard and notify the user that restoration was skipped. Serialize leases process-wide.

Large insertion is chunked only for targets proven to truncate a single paste. Chunks must not contain synthetic Return presses. The original clipboard is restored once.

## 11. Storage

SQLite tables:

```text
schema_migrations
preferences(key, value, updated_at)
dictionary_entries(id, kind, spoken_form, written_form, priority, enabled, created_at, updated_at)
snippets(id, name, trigger, expansion, category, enabled, created_at, updated_at)
styles(id, category, configuration_json, updated_at)
transforms(id, name, instruction, shortcut, preview_required, enabled, updated_at)
transcripts(id, created_at, duration_ms, word_count, app_category, raw_text?, final_text?)
daily_metrics(day, dictations, words, capture_ms, fixes_json, category_counts_json)
model_records(id, path, digest, bytes, language, installed_at, last_verified_at)
```

When history is Never, `raw_text` and `final_text` are not inserted. Metrics are content-free. Retention cleanup runs at launch, after a retention change, and once per day while active.

Use Application Support for the database/models and Caches for reproducible caches. Apply least-permissive file permissions. Use atomic imports and never follow symlinks outside the model directory without explicit user-selected file access.

## 12. Concurrency

- `DictationCoordinator`: active job and transitions.
- `AudioCaptureActor`: audio engine lifecycle.
- `WhisperEngineActor`: model lifetime and inference serialization.
- `DatabaseWriter`: GRDB writer serialization.
- `ClipboardLeaseActor`: cross-app paste isolation.
- UI models: `@MainActor`.

Propagate cooperative cancellation. Set explicit time budgets on context reads, local rewrites, paste confirmation, and model validation.

## 13. Dependency policy

Allow few, reviewed dependencies:

- `whisper.cpp` for ASR.
- GRDB.swift for SQLite.
- A small, reviewed global-hotkey package only if Carbon/AppKit implementation proves fragile.
- Sparkle only after core release packaging is stable.
- `llama.cpp` only for the optional transform target.

Do not add general analytics, networking abstraction, DI framework, UI component library, or embedded browser. Pin exact revisions for native/C++ dependencies and use resolved Swift package versions.

## 14. Distribution architecture

The required Accessibility behavior makes direct Developer ID distribution the primary route. Produce a hardened-runtime, signed, notarized, stapled DMG or ZIP. Add a Homebrew Cask after releases are stable. Keep Sparkle updates opt-in and cryptographically signed if added.

The model weights are not committed to Git. Release notes and the model manager disclose their source, license, size, and checksum.

## 15. Architecture tests

- Production targets other than `ModelDownloadClient` cannot import/use `URLSession`, Network.framework, WebKit, or third-party HTTP clients.
- No content-bearing domain type is interpolated into `Logger`.
- History-off round trip creates no transcript rows and no audio files.
- Secure-field context envelope is empty.
- Clipboard lease restores or safely yields to a newer external clipboard owner.
- Invalid state transitions fail without side effects.
- Every local rewrite is subjected to preservation checks before insertion.
