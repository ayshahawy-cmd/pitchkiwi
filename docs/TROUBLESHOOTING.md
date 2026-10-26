# Troubleshooting PitchKiwi

Start with the latest [community beta](https://github.com/ayshahawy-cmd/pitchkiwi/releases) on an Apple Silicon Mac. Quit extra copies and run the copy in Applications. See the [user guide](USER_GUIDE.md) for normal use.

## macOS blocks the app

This beta is ad-hoc signed and not notarized. Download the ZIP and checksum from the same GitHub Release and verify them. After trying to open the app, go to System Settings → Privacy & Security → Open Anyway, then confirm. Older systems may support Control-click → Open. Follow [Apple's instructions](https://support.apple.com/en-ca/102445). If macOS says a file is damaged, modified, or contains malware, stop and download a fresh copy. Do not disable Gatekeeper globally or remove quarantine recursively.

“Bad CPU type in executable” indicates an unsupported architecture. This release is for Apple Silicon. Download `PitchKiwi-macOS.zip`; the GitHub source archives cannot be opened as an app.

## Fn does nothing or opens Emoji / Apple Dictation

1. Check **Runtime & Privacy → Editor bridge**. Accessibility must be enabled for the installed PitchKiwi copy.
2. Return to PitchKiwi after changing permissions so its status refreshes.
3. In System Settings → Keyboard, set the Fn/Globe action to **Do Nothing** and avoid assigning the same gesture to Apple Dictation.
4. Try the built-in Mac or an Apple keyboard. Many third-party keyboards handle Fn in firmware, outside macOS's view.
5. Try the app's Start/Stop button to distinguish key detection from audio problems.

The shortcut is fixed in this version. There is no shortcut rebinding or separate Fn+Shift prompt shortcut; select Agent Prompt on Command Deck before dictating.

## Microphone or Accessibility permission is missing

Open System Settings → Privacy & Security → Microphone / Accessibility and enable PitchKiwi. Check that you launched the copy you granted, rather than an old build or an app in Downloads. Quit and reopen after changing a grant if needed.

Ad-hoc signatures change on rebuild. If toggling a grant does not help, remove the stale Accessibility entry, add the current app, and enable it again. As a last resort, reset **only PitchKiwi's** grants, then relaunch and authorize again:

```bash
tccutil reset Accessibility com.pitchkiwi.app
tccutil reset Microphone com.pitchkiwi.app
```

These commands remove permission approvals, not app data. They do not grant access automatically.

## No waveform, no speech, or the wrong microphone

Check Microphone permission and the input device/level under System Settings → Sound → Input. The app uses the system input; it has no dedicated device picker yet. Reconnect a disconnected microphone and try again. Use a clear sentence longer than a click or single syllable. Silence and uncertain recognition are deliberately rejected.

## “No local model found” or model import fails

Official app ZIPs include the default model. A developer build made without bootstrap may omit it. Run `./scripts/bootstrap.sh` and `./scripts/build-app.sh` from the checkout, or import a trusted compatible `.bin` in Runtime & Privacy.

Imports require a `.bin` extension, a GGML header, and a size greater than 1 MB and no larger than 4.5 GB. A file passing these checks can still be incompatible with the native parser. A `.gguf`, Core ML bundle, HTML download page, Git LFS pointer, or compressed archive is not the expected model. Re-download the model and verify its provider's SHA-256. Arbitrary imports are not automatically authenticated.

## Recognition is slow or inaccurate

The first recognition loads the model and initializes Metal. Processing occurs after you stop speaking. Close memory-intensive apps, check input level, and use shorter captures. The release includes `base.en` for English; larger compatible English models can improve accuracy at the cost of RAM and processing time.

Add recurring terms to Project Dictionary. Compare **Show original** with cleaned output to distinguish recognition from cleanup changes. Use Agent Prompt: Short for the closest prompt to your words. Turn off **Compile syntax** if developer-symbol rules are unwanted. There is no cloud accuracy setting or API key.

## Text appears in the app but not at the destination

Use an editable text field and keep the target app focused while transcription finishes. Secure fields are blocked. Switching applications can reject insertion. Some apps do not expose a writable Accessibility range or ignore synthetic paste.

Try TextEdit to isolate the problem. Check the editor bridge, then choose Copy on the latest result and paste manually. Chromium and Electron use a guarded clipboard fallback. There is no adjustable paste-delay preference. If the wrong clipboard item appears, recover with Copy and report the target application/version using synthetic text. Include whether a clipboard utility or key remapper was active.

## History or settings behavior is surprising

History starts at Never. The latest result remains in memory; aggregate counters persist. A retention change prunes saved history immediately, and launch prunes expired records; a daily background timer is not implemented. Dictionary and macros remain after **Clear history & metrics**.

Data lives in `~/Library/Application Support/PitchKiwi/pitchkiwi.json`. Do not post this file to GitHub: it may contain private text. Quit before copying it for your own backup. Removing the app leaves this data in place. Old VibeFlow development data may be migrated into the PitchKiwi folder.

## Build or bootstrap fails

See [development setup](DEVELOPMENT.md). A SHA-256 mismatch is a failed integrity check; do not edit the expected checksum to make it pass. A missing `.vendor/whisper.xcframework` means bootstrap did not finish. A missing SDK or SwiftUI error may mean Command Line Tools are selected instead of full Xcode. Check `xcode-select -p`, `xcodebuild -version`, and `swift --version`.

## Report a bug

Use the [bug form](https://github.com/ayshahawy-cmd/pitchkiwi/issues/new/choose). Include app version/build or commit, Mac chip, macOS version, model, permission state, target app, reproduction steps, and expected versus actual behavior. For build failures, include the failing command and a redacted diagnostic excerpt. Use made-up dictation and remove personal paths, tokens, recordings, clipboard contents, and private source. Security disclosures belong in [private reporting](../SECURITY.md).
