# PitchKiwi user guide

PitchKiwi converts speech into text on your Mac and inserts it into the text field you selected. English speech recognition uses a local Whisper model. Cleanup and prompt formatting use Swift rules and fixed templates; no cloud account, API key, or second language model is required.

## Requirements

- An Apple Silicon Mac, M1 or newer. The downloadable app contains an arm64 executable. Intel Macs, Windows, Linux, and iOS are not supported by this release.
- macOS 14 Sonoma or newer. Glass effects use newer system APIs when available and fall back on older supported systems.
- Microphone and Accessibility access for global dictation.
- Space for the app and bundled model; the model is approximately 148 MB. Building from source needs additional space for the framework and build caches.

## Download and verify

1. Visit [GitHub Releases](https://github.com/ayshahawy-cmd/pitchkiwi/releases).
2. Download **`PitchKiwi-macOS.zip`** and **`PitchKiwi-macOS.zip.sha256`** from the same release. GitHub's “Source code” files are not the app.
3. With both files in Downloads, optionally verify the archive in Terminal:

   ```bash
   cd ~/Downloads
   shasum -a 256 -c PitchKiwi-macOS.zip.sha256
   ```

   Expect `PitchKiwi-macOS.zip: OK`. A mismatch means the files do not belong together or the archive changed; download both again before opening. A matching checksum confirms consistency with the published checksum, not an independent security review.

Downloads are public. No email signup or payment is required.

## Installation and first launch

1. Unzip the archive and move `PitchKiwi.app` into Applications.
2. Open the app from Applications.
3. This community beta is ad-hoc signed and **not notarized**. If blocked, first check the release and checksum, then follow [Apple's instructions](https://support.apple.com/en-ca/102445): after attempting to launch, open **System Settings → Privacy & Security**, choose **Open Anyway**, and confirm. Older systems may also offer Control-click → Open. Do not use a global Gatekeeper override.
4. Complete the four-step onboarding. Enable Microphone for speech capture and Accessibility for the Fn key and text insertion. Return to PitchKiwi so the permission indicators refresh.
5. Open TextEdit, make a new plain-text document, and place the cursor in it before your first dictation.

Keep a single installed copy. Rebuilt ad-hoc apps can need fresh permission grants even when the bundle identifier is unchanged.

## Your first dictation

1. In **Command Deck**, choose **Dictation**.
2. Click the destination text field in TextEdit, your editor, or a browser.
3. Hold **Fn/Globe**, say a short sentence, then release.
4. The waveform indicates capture; transcription and cleanup begin after release.
5. Review the inserted text. PitchKiwi does not press Return or submit the field.

For hands-free capture, double-press Fn, speak, then press Fn again to finish. **Escape** cancels the active job. If Fn launches Emoji, changes input source, or triggers Apple Dictation, set its system action to **Do Nothing** in Keyboard settings. Some third-party keyboards do not expose Fn to macOS; use an Apple keyboard or the app's Start/Stop controls.

Avoid changing the destination while recognition is in progress. If insertion fails or the target app changes, the latest result remains in PitchKiwi. Choose **Copy** or **Open in scratchpad** to recover it. Copy is an explicit clipboard replacement; automatic insertion attempts to restore the previous clipboard after its paste fallback.

## Dictation and Agent Prompt

Choose the output mode before capture:

| Mode | Behavior |
| --- | --- |
| Dictation | Keeps the basic order of your speech while removing supported filler, repetition, and explicit false starts, then applies dictionary, macro, punctuation, and developer rules |
| Agent Prompt: Short | Organizes explicit cues into Goal, Context, Requirements, and Done when; omits absent sections |
| Agent Prompt: Medium | Adds a fixed execution and validation brief to the organized request |
| Agent Prompt: Detailed | Adds a longer fixed workflow and deliverable brief |

Use cues such as “for context,” “make sure,” and “done when” when you want predictable sections. Medium and Detailed add process guidance, so choose Short for the closest representation of what you said. The templates do not inspect your project or execute the request. **Show original** lets you compare recognition output with cleanup when they differ.

## Project Dictionary

Open **Project Dictionary**, enter the spoken form and exact written form, and choose **Add**. For example, map “super base” to `Supabase` or a commonly misheard project name to its correct spelling. Dictionary entries are stored locally and enabled entries supply bounded recognition hints. Initial developer entries are seeded once; this is not automatic learning from your speech. Delete a row using its trash button.

## Voice Macros

Open **Voice Macros**, enter a name, spoken trigger, and expansion, then add the macro. Speak the exact trigger as the whole utterance to expand it, or use the supported `insert snippet` phrase. Use distinctive triggers; duplicate normalized triggers do not expand automatically. Expansion text is output, not an instruction for PitchKiwi to execute. Inspect multiline expansions before pasting into terminals or tools.

## Output Rules and Prompt Lab

**Output Rules → Compile syntax** enables developer formatting. Supported examples include `camel case user id` → `userId`, `snake case refresh token` → `refresh_token`, `dot env` → `.env`, and `dash dash force` → `--force`. Recognition and punctuation can affect the matching rules. The current implementation is a deterministic formatter, not a general code translator.

**Prompt Lab** lets you place text in a scratchpad, use the latest capture, and apply local cleanup or prompt assembly. It does not run an autonomous agent, edit a project, or call an external rewrite model. Generated text must be reviewed before use.

## Runtime & Privacy

| Control | Current behavior |
| --- | --- |
| Global capture key | Displays the fixed Fn gesture; arbitrary shortcut rebinding is not implemented |
| Local speech model → Import .bin | Copies a selected compatible Whisper GGML model into Application Support and selects it |
| Editor bridge | Opens Accessibility setup and displays current trust status |
| Transcript history | Never by default; optionally 24 hours, 7 days, 30 days, or Forever |
| Nearby text context | Off by default; when enabled, reads at most 2,000 nearby characters and reduces them to at most 40 recognition hints |
| Clear history & metrics | With confirmation, deletes stored transcripts and aggregate counters; dictionary and macros remain |

Audio remains in memory and is not saved. History-off dictation retains only the latest result in memory and content-free totals on disk. History retention is pruned on launch and when the setting changes; a continuously running app does not currently prune on a daily timer. A shorter setting prunes immediately. Context skips recognized secure fields and does not read full documents or screenshots.

Local settings, dictionary, macros, metrics, and optional history live at:

```text
~/Library/Application Support/PitchKiwi/pitchkiwi.json
~/Library/Application Support/PitchKiwi/Models/
```

The app also uses macOS preferences for onboarding and the selected model filename. The JSON file has owner-only permissions but is not independently encrypted. Backups and software running as your user may access local files. Clipboard managers may observe temporary fallback paste text. These boundaries are described in [security and privacy design](SECURITY.md).

## Models and offline use

Release ZIPs include `ggml-base.en.bin`; you can dictate offline after installation. The native app does not download models automatically. Source builds fetch dependencies through the bootstrap script before packaging. Import a compatible English `.bin` model under Runtime & Privacy if needed. Imports check the extension, size, and GGML header; arbitrary imported files are **not** authenticated against a trusted digest catalog. Obtain them from a trusted source and verify the provider's checksum yourself. The bundled default is checksum-pinned during packaging.

The decoder currently uses English. Importing a multilingual model does not add a language selector or guarantee non-English behavior. Larger models require more RAM and disk and can be slower. To return to the default, import the trusted `ggml-base.en.bin` model again.

## Updates and removal

Updates are manual: quit PitchKiwi, download the new release ZIP, verify it, and replace the copy in Applications. Reopen and check permissions. There is no automatic updater, launch-at-login control, or App Store distribution in this beta.

To uninstall, quit the app and move it to Trash. This does **not** remove Application Support data. To remove that data too, use Finder → Go → Go to Folder, enter `~/Library/Application Support/PitchKiwi`, and remove the folder after making any backup you want. This removes imported models, dictionary, macros, history, and counters. Remove PitchKiwi's Microphone and Accessibility grants in System Settings if desired. Deleting files is not a guarantee of forensic erasure or removal from backups.

## Known limitations

- The release is an ad-hoc signed, unnotarized community beta. Minimum macOS support is declared in the bundle; validation on every supported OS version has not been completed.
- Recognition starts after capture ends; there are no live partial transcripts.
- Capture buffers retain up to five minutes of audio. Stop earlier: capture beyond that point is not included, and there is no automatic five-minute stop or advance warning yet.
- Fn is fixed. Some hardware does not expose it, and macOS key assignments can conflict.
- English-first decoding, model errors, and deterministic rules can misrecognize names or change intended wording. Review the result and compare the original when needed.
- Cross-app insertion depends on the target's Accessibility and paste behavior. There is no universal delivery acknowledgment, selected-text diff workflow, or automatic undo guarantee.
- Designs for local LLM transforms, custom rewrite prompts, app-specific profiles, signed model catalogs, and SQLite are future work. Current storage is JSON and current cleanup is deterministic.
- Automated tests cover specific behaviors; they do not establish a complete end-to-end privacy audit or compatibility with every editor. See [release verification](RELEASE_VERIFICATION.md).

For help, read [troubleshooting](TROUBLESHOOTING.md), then open a [bug report](https://github.com/ayshahawy-cmd/pitchkiwi/issues/new/choose) using synthetic examples. Report security vulnerabilities [privately](../SECURITY.md).
