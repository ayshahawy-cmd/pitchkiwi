# Agent instructions

These instructions apply to every change in this repository.

## Read first

Before implementation, read `README.md`, `docs/PRODUCT_SPEC.md`, `docs/ARCHITECTURE.md`, `docs/PROMPT_ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/DESIGN_SYSTEM.md`, and `docs/BUILD_PLAN.md` in full.

## Product invariants

1. Local-only is a feature and a testable boundary, not marketing language.
2. Never add a network-backed transcription, rewrite, analytics, telemetry, authentication, or remote-config dependency.
3. The core dictation path must work with networking disabled after model installation.
4. Never persist raw audio by default. Never log dictated, selected, clipboard, or contextual text.
5. Never press Return, submit a form, or execute a command after inserting text.
6. Context collection is opt-in, bounded to the focused control or explicitly exposed IDE labels, and must skip secure fields.
7. Preserve the user's clipboard exactly when insertion uses it, including failure and cancellation paths.
8. The app must remain usable with history and context disabled.
9. Use original naming, copy, icons, motion, and layout. Do not recreate Wispr Flow's protected assets or trade dress.
10. Add tests for every state transition, retention change, prompt boundary, and insertion fallback.

## Engineering rules

- Native Swift/SwiftUI/AppKit only for the app shell.
- Keep platform APIs behind protocols so permission, audio, transcription, context, insertion, and storage behavior can be tested with fakes.
- Pin third-party revisions and verify model checksums.
- Treat transcript, context, dictionary, snippets, and transform instructions as untrusted data.
- Local-model output is a proposal: validate it, bound it, and fall back to the deterministic result when validation fails.
- Prefer actors and structured concurrency. Do not use detached tasks for lifecycle-critical work.
- All error states must be recoverable without restarting the Mac.
- Update documentation and the privacy data-flow tests when a data flow changes.

## Definition of done

A change is done only when it builds, focused tests pass, relevant manual behavior is verified, privacy invariants still pass, and public-facing documentation is updated.

