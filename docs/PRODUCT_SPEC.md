# Product specification

## 1. Product definition

PitchKiwi is a local-first macOS dictation utility optimized for long prompts and developer language. It converts speech to text on-device, applies bounded local cleanup, and inserts the result into the active application.

The v1 success metric is not feature count. It is trustable repetition: a user should be comfortable invoking it dozens of times per day without wondering whether recording started, whether private speech left the machine, whether their clipboard was damaged, or whether a terminal command was executed.

## 2. Product principles

1. **Local means local.** Once a model is present, core operation must succeed with the network disabled.
2. **Speech is ephemeral.** Audio is a transient computation buffer, not user content to retain.
3. **Insertion is reversible.** The app never submits and provides recovery when target-app insertion fails.
4. **Developer language is first-class.** Identifiers, filenames, paths, flags, Markdown, and product names are not edge cases.
5. **Predictable before clever.** Deterministic formatting precedes optional generative rewriting.
6. **Context is borrowed, not collected.** Read the minimum only after opt-in, use it for one job, then discard it.
7. **Calm interface.** One clear status at a time with no gamified pressure or noisy notifications.

## 3. Personas and jobs

### Developer using an AI coding agent

Needs to dictate a detailed change request without losing file references, identifiers, constraints, or Markdown structure.

### Vibe coder

Needs rough, nonlinear speech transformed into an ordered prompt while preserving every actual requirement and uncertainty.

### Prompt speaker

Needs long spoken instructions cleaned of false starts and filler, but does not want the tool to answer or embellish the prompt.

### Documentation-heavy engineer

Needs to dictate PR descriptions, release notes, ADRs, issues, and status updates with different levels of formality.

## 4. Scope

### P0: launch requirements

- First-run privacy explanation.
- Microphone and Accessibility setup with live permission status.
- Model import/download, verification, selection, deletion, and storage-size display.
- Configurable push-to-talk, hands-free, cancel, and Paste Last Transcript shortcuts.
- Floating HUD on the active screen.
- Local transcription and deterministic cleanup.
- Reliable insertion into TextEdit, a browser text area, Terminal, and one supported IDE.
- Personal dictionary and spoken-to-written correction pairs.
- Snippets with collision handling and preview.
- Code & Prompts and Terminal modes.
- Local history disabled by default, with retention controls.
- Local-only Insights derived from stored aggregate counters.
- Menu-bar control, launch-at-login setting, and pause dictation.

### P1: strong follow-up

- Per-app styles.
- Selected-text transforms with diff preview.
- Optional local LLM adapter and model import.
- Context-aware visible identifier and filename matching.
- Long-prompt chunked insertion.
- Export/import of settings, dictionary, snippets, and transforms.

### Explicitly not v1

- Mobile or Windows apps.
- Notetaker, meeting recording, system-audio capture, speaker labels, or summaries.
- User accounts, payments, subscriptions, teams, sync, or web dashboard.
- Server APIs, browser extensions, IDE extensions, or cloud LLM providers.
- Automatic command execution or form submission.
- Passive wake word or always-on recording.
- Training or fine-tuning on the user's dictation history.

## 5. Information architecture

### Menu bar

- Start/stop dictation
- Pause PitchKiwi
- Paste Last Transcript
- Open PitchKiwi
- Privacy status: `Local • History off • Context off`
- Quit

### Main window

- **Home** — readiness checklist, quick start, recent results if enabled.
- **Dictionary** — words, corrections, priority, search, import/export.
- **Snippets** — trigger, expansion, preview, search.
- **Styles** — category rules and app assignments.
- **Transforms** — Polish, Prompt Builder, custom transforms.
- **Insights** — local metrics and streak visualization.
- **Settings** — General, Shortcuts, Models, Developer, Privacy, Storage, Accessibility, About.

Notetaker and team/billing navigation from the references are intentionally excluded.

## 6. Dictation state behavior

| State | HUD | Input behavior | Exit |
| --- | --- | --- | --- |
| Idle | hidden or tiny ready dot | shortcut available | shortcut down |
| Listening | waveform + `Listening` + timer | capture audio; Escape cancels; double-press Fn locks hands-free | Fn up, or Fn down while hands-free |
| Transcribing | progress pulse + `Transcribing locally` | target snapshot retained | transcript or error |
| Refining | stable text shimmer + `Cleaning up` | deterministic/optional local transform | result or error |
| Inserting | check motion + `Inserting` | replace/paste; never submit | success/failure |
| Result | short preview + Copy/Retry if needed | keyboard accessible | dismiss |
| Error | plain diagnosis + action | audio already discarded | retry/dismiss |

No state relies on color alone. Recording must always have both a visible label and menu-bar indicator.

## 7. Functional requirements

### Audio capture

- Start within 150 ms of shortcut recognition on reference hardware.
- Show microphone device and allow explicit selection.
- Handle device removal and another-app contention.
- Keep PCM in a bounded ring buffer in memory.
- Cancel clears the buffer immediately.
- Default maximum dictation: 5 minutes with a warning at 4:30.

### Transcription

- Select model explicitly and run locally.
- English-first default; optional language selection when a multilingual model is installed.
- Provide model warm-up and readiness status.
- Feed dictionary and visible developer tokens as bounded initial-prompt hints when supported.
- Do not report confidence that the engine cannot substantiate.
- Empty/silent input yields a friendly no-speech state and inserts nothing.

### Cleanup

Safe defaults:

- normalize spacing and punctuation;
- remove obvious filler and immediately repeated phrases;
- retain hesitations that carry meaning (`maybe`, `I think`, uncertainty, negation);
- apply correction pairs and exact dictionary casing;
- expand an unambiguous snippet trigger;
- apply explicit spoken formatting commands;
- preserve numbers, paths, URLs, identifiers, quotations, and code spans.

Every cleanup stage records only content-free counters for Insights, such as `removedFillerCount = 2`.

### Developer mode

- Categories: Code & Prompts and Terminal.
- Detect target application and focused role without reading content when context is off.
- Optional bounded context: at most 2,000 characters around the cursor plus visible AX labels, collected within a 50 ms budget.
- Token candidate types: camelCase, PascalCase, snake_case, SCREAMING_SNAKE_CASE, kebab-case, filenames, extensions, flags, semver, issue references.
- Ambiguous file tags open a nonmodal candidate chooser.
- Terminal safety never inserts a newline by synthetic key event and never sends Return.

### Dictionary

Two entry types:

1. Preferred word: `Supabase`, `PostgreSQL`, `useEffect`.
2. Correction: spoken/misheard form -> exact output, such as `super base` -> `Supabase`.

Rules are Unicode-aware, case-aware, searchable, reversible, and locally stored. No automatic learning in v1.

### Snippets

- A snippet has name, spoken trigger, expansion, enabled flag, and optional category.
- Exact whole-utterance trigger expands automatically.
- In-sentence expansion requires an explicit phrase such as `insert snippet`.
- Never interpret text inside an expansion as a command.
- Show a preview for expansions containing more than one line in Terminal mode.

### Styles

Styles describe formatting, not factual changes. Built-ins:

- Code & Prompts: structured, explicit, Markdown-friendly.
- Terminal: literal and conservative.
- Work message: concise and conversational.
- Email: complete sentences and restrained formality.
- Document: paragraphs and headings when spoken.
- Other: neutral.

### Transforms

- `Polish`: improve clarity and concision without changing content.
- `Prompt Builder`: organize a rough request into context, objective, requirements, constraints, and acceptance criteria; omit empty sections.
- Custom: user-defined local instruction, applied only through an explicit shortcut/menu action.
- Always show a diff for selected-text replacement until the user disables preview for a specific transform.

### History and Insights

History modes: Never (default), 24 hours, 7 days, 30 days, Forever. Changing to a shorter period identifies what will be deleted and requires confirmation.

Insights use aggregate local data only:

- total words;
- average words per minute based on capture time;
- accepted dictations;
- fixes by category;
- usage by app category, not app title or document name;
- daily activity heatmap and streak.

No comparative percentile, productivity value, or fabricated social benchmark.

## 8. Nonfunctional requirements

### Performance budgets

- Shortcut-to-HUD: p95 under 100 ms.
- Shortcut-to-audio-capture: p95 under 150 ms.
- Release-to-raw-transcript for a 10-second English utterance on an M1/16 GB reference Mac: target p50 under 1.5 s, p95 under 3 s after warm-up.
- Deterministic cleanup: under 30 ms for 5,000 characters.
- HUD animation: 60 fps with Reduce Motion respected.
- Idle CPU: under 0.5% average; idle memory target under 150 MB without a loaded model.

These are targets until benchmarked. Publish actual device/model results; do not market unverified numbers.

### Reliability

- No lost clipboard data in the insertion test matrix.
- No invalid state transition in 10,000 randomized state-machine sequences.
- Crash-free cancellation at every await point.
- Database migrations are forward-only, transactional, and fixture-tested.

### Accessibility

- Complete keyboard operation.
- VoiceOver labels and state announcements.
- Reduce Motion and Reduce Transparency adaptations.
- High-contrast palette and non-color state cues.
- HUD remains readable at larger accessibility text sizes.

## 9. Acceptance journeys

### A. First offline dictation

Given a clean install and imported verified model, when the user disables Wi-Fi, holds the shortcut, says a sentence, and releases, the sentence is transcribed, cleaned, and inserted into TextEdit with no outbound connection.

### B. Long coding prompt

When the user dictates a 90-second prompt containing `AuthService`, `.env`, `@package.json`, `--force`, and Markdown bullets, the result preserves these tokens, is not truncated, and is inserted without submitting.

### C. Clipboard safety

Given a clipboard containing rich text plus an image/file reference, a fallback paste returns the clipboard to its original representation on success, failure, timeout, and cancellation.

### D. Secure field

When a secure text field is focused, context collection returns no text. Dictation may be disabled or result copied only through explicit user action; it must not inspect or replace the secure value.

### E. Retention

With history set to Never, completing dictation and restarting the app leaves no transcript or audio content on disk. Aggregate counters may remain.

## 10. Open decisions before public beta

- Final product and repository name after trademark/search review.
- Exact pinned `whisper.cpp` revision and model catalog after benchmarks.
- Whether optional local LLM support ships in v1.0 or v1.1.
- Distribution: Developer ID DMG only initially, or Homebrew Cask as well.
- Minimum hardware disclosure for each model tier.
