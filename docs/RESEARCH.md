# Reference research

Research checked on 2026-09-15. Product behavior changes over time; verify links again before implementation decisions or public claims.

## OpenAI Whisper

OpenAI describes Whisper as an open-sourced encoder-decoder Transformer trained on 680,000 hours of multilingual and multitask supervised audio. Audio is processed in 30-second chunks after conversion to a log-Mel spectrogram; the system supports transcription, language identification, phrase-level timestamps, and translation to English.

Sources:

- [OpenAI: Introducing Whisper](https://openai.com/index/whisper/)
- [OpenAI Whisper repository](https://github.com/openai/whisper)
- [OpenAI Whisper model card](https://github.com/openai/whisper/blob/main/model-card.md)

OpenAI's repository states that the code and model weights are released under the MIT License and lists model size/speed tradeoffs. Preserve the upstream notices and independently verify the exact artifact license and checksum used by this project.

## Local macOS inference

`whisper.cpp` is a C/C++ implementation designed for efficient local inference and supports Apple Silicon acceleration, Metal, Core ML, quantization, and a C-style API. Its repository includes SwiftUI and Apple framework examples. The older standalone `whisper.spm` repository says to use the package directly from `whisper.cpp`, so implementation should follow the maintained upstream route and pin a reviewed revision.

Sources:

- [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [whisper.cpp SwiftUI example](https://github.com/ggml-org/whisper.cpp/tree/master/examples/whisper.swiftui)
- [whisper.cpp XCFramework build script](https://github.com/ggml-org/whisper.cpp/blob/master/build-xcframework.sh)
- [whisper.spm maintenance notice](https://github.com/ggerganov/whisper.spm)

## Wispr Flow behavior worth studying

The supplied `/so` URL currently returns a not-found page. The main site, developer page, screenshots, and public help documentation establish the relevant product patterns.

Verified public behavior includes:

- hold a hotkey, speak, release, and insert into the active app;
- automatic cleanup of filler, repetition, punctuation, and style;
- custom dictionary, correction pairs, snippets, styles, transforms, history, and Insights;
- developer terms, camelCase/snake_case handling, visible identifier matching, file tagging in selected IDE chat panels, and long-prompt handling for coding CLIs;
- Accessibility permission for cross-app insertion/context on macOS;
- preservation/restoration of the clipboard around paste;
- a floating desktop control plus a larger management hub;
- a current cloud-based transcription path and optional cloud storage/privacy controls.

Sources:

- [Wispr Flow homepage](https://wisprflow.ai/)
- [Flow for Developers](https://wisprflow.ai/developers)
- [What is Flow?](https://docs.wisprflow.ai/articles/2772472373-what-is-flow)
- [Use Flow with Cursor, VS Code, and other IDEs](https://docs.wisprflow.ai/articles/6434410694-use-flow-with-cursor-vs-code-and-other-ides)
- [Context Awareness](https://docs.wisprflow.ai/articles/4678293671-Context-Awareness)
- [Create and use snippets](https://docs.wisprflow.ai/articles/5784437944-create-and-use-snippets)
- [How to use Transforms](https://docs.wisprflow.ai/articles/8068950331-how-to-use-transforms-beta)
- [Security and compliance FAQ](https://docs.wisprflow.ai/articles/3467817258-security-and-compliance-faq)

## What is not established

Wispr Flow's complete proprietary application/backend stack, exact models, prompts, training approach, private services, and source architecture are not public in the material reviewed. This repository must not present guessed technology as fact.

The architecture here is an independent recommendation based on the required behavior:

- native SwiftUI/AppKit for macOS integration;
- `whisper.cpp` for offline ASR;
- deterministic local developer-aware cleanup;
- optional local `llama.cpp` adapter for richer transforms;
- SQLite/GRDB for local data;
- direct Developer ID distribution for Accessibility-heavy behavior.

## Product differences by design

PitchKiwi should omit cloud sync, accounts, teams, mobile, meeting recording, subscriptions, referrals, and cloud-based learning. It should add stricter local context bounds, terminal-safe insertion, offline verification, history-off default, model checksum transparency, and a public threat model.

