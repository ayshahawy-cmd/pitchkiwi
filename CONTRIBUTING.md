# Contributing

Thanks for helping build a private, local dictation tool for macOS.

Before opening a code change, read `AGENTS.md` and the documents in `docs/`. Privacy, non-submission, clipboard preservation, and original design are project invariants.

Use the [development guide](docs/DEVELOPMENT.md) for a complete clean-checkout setup. Install dependencies with `make bootstrap`, then run `swift build` and `swift test`. Create a branch in your fork and submit a pull request to `main`. Builds require no secrets or paid Apple account.

By contributing, you agree that your contribution may be distributed under this repository's [MIT License](LICENSE). Submit only work you have the right to license. No contributor license agreement is currently required. Follow the [code of conduct](CODE_OF_CONDUCT.md).

## Before a pull request

- Open or reference an issue for user-visible or architectural changes.
- Keep the change focused and explain any new data flow or permission.
- Add or update tests.
- Run `swift build` and `swift test`. Use `./scripts/build-app.sh` when changing packaging, resources, or the application target.
- Update documentation and `CHANGELOG.md` for user-visible behavior.
- Do not include recordings, real transcripts, model weights, database files, logs, secrets, signing assets, or screenshots containing personal data.

## Design contributions

Use original assets and copy. References to other products may explain interaction patterns but must not be used to reproduce proprietary visuals, wording, icons, or trade dress.

## Security contributions

Do not open a public issue for a vulnerability that could expose recorded audio, transcript content, local context, clipboard contents, signing keys, or release infrastructure. Follow [SECURITY.md](SECURITY.md).

## Tests and fixtures

Use synthetic speech/text and public-domain audio only. Every fixture must include its provenance and license. A contributor must have permission from every speaker in a submitted recording.
