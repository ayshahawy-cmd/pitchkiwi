# Security and privacy design

## 1. Security claim

Horme Flow is designed so normal dictation, cleanup, personalization, history, and Insights can run without sending data off the Mac. “Local-first” must be demonstrated by architecture and tests; it must not depend on a privacy-policy promise.

The app still processes highly sensitive data inside the user's session. Local software can leak through logs, clipboard behavior, overly broad Accessibility access, unsafe model loading, backups, or other local applications. This document treats those as first-class risks.

## 2. Data inventory

| Data | Default lifetime | Storage | Network |
| --- | --- | --- | --- |
| Microphone PCM | one dictation job | memory only | never |
| Raw transcript | one job | none unless history enabled | never |
| Final transcript | last result in memory | optional local DB | never |
| Focused-field context | one job, opt-in | never | never |
| Dictionary/corrections | until user deletes | local DB | never |
| Snippets/transforms | until user deletes | local DB | never |
| Aggregate metrics | until user deletes | local DB, content-free | never |
| Model weights | until user deletes | local model directory | explicit download only |
| Logs | rotating, short retention | local unified log | never; no content |

## 3. Trust boundaries

- **Microphone boundary:** AVFoundation supplies audio only while explicit recording state is visible.
- **Accessibility boundary:** other apps expose focused roles and optional bounded content.
- **Inference boundary:** native model libraries parse large, potentially untrusted model files and audio.
- **Clipboard boundary:** other apps and clipboard managers may observe temporary paste content.
- **Storage boundary:** local processes, backups, malware, and another account with device access may reach files.
- **Download boundary:** the model host and transport may be compromised.
- **Transform boundary:** source/context may contain prompt-injection text even though inference is local.

## 4. Threats and controls

### Accidental recording

Controls:

- push-to-talk default;
- clear HUD label, waveform, timer, menu-bar state, and optional sound cue;
- Escape cancellation everywhere;
- automatic maximum duration;
- no launch-time or wake-word capture;
- audio engine stops on screen lock, sleep, fast user switching, and permission revocation.

### Content in logs or crash reports

Controls:

- no third-party crash uploader;
- wrapper logger accepts typed event enums and numeric timings, not freeform values;
- debug descriptions of audio/transcript/context types are redacted;
- CI tests scan log calls for content-bearing fields;
- support bundle shows the exact metadata it will export and never includes content by default.

### Clipboard interception or damage

Controls:

- prefer direct Accessibility replacement;
- serialize fallback paste operations;
- preserve every pasteboard representation, not text alone;
- mark temporary values transient/concealed where the platform supports it;
- restore after paste confirmation, but never overwrite a clipboard changed by another process;
- offer direct AX insertion or in-app result for users with sensitive clipboard policies.

The UI must disclose that macOS cannot guarantee invisibility from every third-party clipboard utility.

### Excessive context reading

Controls:

- context off by default;
- separate permission explanation and setting;
- secure-field detection, app denylist, field-role allowlist;
- bounded window around cursor and strict collection timeout;
- no screenshots, OCR, full document reads, browser history, pasteboard reads, or background window traversal;
- ephemeral job value cleared on completion;
- optional HUD badge when context was used.

### Unsafe insertion

Controls:

- snapshot and revalidate the target application/focused element;
- never synthesize Return or submit events;
- terminal safety preview for multiline or control-operator content;
- no automatic password-field insertion;
- selected-text replacement retains an undo receipt where possible;
- failed or changed target falls back to result card, not a guessed window.

### Malicious/corrupted model

Controls:

- catalog pins source, byte length, license, and SHA-256;
- download to a temporary nonexecutable file, stream hash, then atomic move;
- imported models are size-bounded, format-validated, and explicitly selected by the user;
- no arbitrary dynamic libraries, scripts, Python environments, or executable plugins;
- document that native model parsers expand the attack surface and keep dependencies updated through reviewed PRs.

### Prompt injection and harmful rewrite

Controls:

- immutable local transform contract;
- source, context, dictionary, and custom prompts serialized as data;
- protected-span manifest and post-generation validation;
- output-length bounds, timeout, schema validation, cancellation, and deterministic fallback;
- no tool use or network access from the local rewrite engine;
- diff preview for selected-text transforms.

### Local database exposure

Controls:

- history off by default;
- least-permissive directory/file modes;
- exclude data directory from in-app exports unless explicitly selected;
- one-click delete and automatic retention cleanup;
- no secrets in SQLite; use Keychain when a future feature truly needs a secret;
- optional database encryption is a later feature and must not be marketed as solving access by malware in the same logged-in session.

### Supply chain and release compromise

Controls:

- pin native dependency commits and checksums;
- commit `Package.resolved`;
- GitHub Actions with least privilege and pinned action revisions;
- dependency review, secret scan, license inventory, reproducible model catalog;
- signed/notarized artifacts with published SHA-256 checksums;
- protected release environment and no signing secrets in forks.

## 5. Permissions

### Microphone

Ask during onboarding after explaining that audio is processed locally and not retained. A denial leaves the rest of the app navigable and offers a direct route to settings.

### Accessibility

Ask only when enabling global insertion/context features. Explain separately:

- insertion permission lets Horme Flow place text at the cursor;
- context, if enabled, can read a small amount of nearby text to recognize local tokens.

Accessibility permission does not automatically enable context. Revocation must stop collection/insertion immediately and preserve the result in-app.

Cross-app dictation must not begin while Accessibility trust is absent. The app opens the system permission pane and refreshes status when it becomes active again, preventing successful transcription from ending in a predictably blocked insertion.

### Network

Network access is needed only for user-initiated model downloads and optional update checks. Model import supports a no-network machine. If update checks are added, make them separate, opt-in, and content-free.

## 6. Retention and deletion

- `Never`: no transcript text on disk.
- `24 hours`, `7 days`, `30 days`, `Forever`: local DB only.
- Raw audio: never stored in release builds.
- Last transcript: in memory until replaced, app quits, or user clears it.
- Delete All removes transcript rows, metrics, dictionary, snippets, transforms, imported models, and caches only after listing categories and receiving confirmation.
- Secure deletion cannot be guaranteed on SSD/APFS; describe deletion honestly as logical removal and key/file deletion, not forensic erasure.

## 7. Offline verification

Provide a reproducible script/test that:

1. installs/imports a model;
2. denies app network access or runs under a network-blocking harness;
3. performs a recorded fixture transcription and refinement;
4. inserts into a test text control;
5. asserts zero DNS/TCP/UDP activity from the process;
6. scans the app container for fixture transcript/audio bytes under history-off mode.

The project README must publish the result and environment for each release candidate.

## 8. Security release checklist

- Threat model updated for changed data flows.
- Dependencies and licenses reviewed.
- Model catalog checksums verified from a clean machine.
- Offline and no-persistence tests pass.
- Secure-field, target-switch, clipboard-race, and cancellation tests pass.
- Logs scanned with canary transcript, email, URL, path, and identifier values.
- Entitlements contain only documented requirements.
- Hardened runtime, code signing, notarization, and artifact checksum verified.
- `THIRD_PARTY_NOTICES.md` generated.
- Known limitations documented without overstating privacy guarantees.

## 9. Vulnerability handling

See the repository-level `SECURITY.md`. Do not ask reporters to attach private recordings or transcripts. Provide synthetic reproduction instructions and a private contact path before public beta.
