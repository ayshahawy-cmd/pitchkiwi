# Security policy

Report vulnerabilities using [GitHub Private Vulnerability Reporting](https://github.com/ayshahawy-cmd/pitchkiwi/security/advisories/new). Reports are private to repository maintainers and invited collaborators until an advisory is published. Do not open a public issue for an undisclosed vulnerability.

Include the version or commit, macOS version, affected component, expected impact, and minimal synthetic reproduction steps. Do not submit real recordings, transcripts, clipboard contents, local context, credentials, or private project data, even in a private report. If the reporting link is unavailable, contact [the maintainer](https://github.com/ayshahawy-cmd) to request a private channel without disclosing vulnerability details.

## Supported versions

| Version | Security fixes |
| --- | --- |
| Latest published 0.8.x beta | Best effort; upgrade to the latest beta |
| `main` | Active development; fixes land here first |
| Older beta versions | No backports promised |

This is a volunteer-maintained beta. There is no guaranteed response time or security audit claim. Maintainers should acknowledge a report, investigate with synthetic data, prepare a fix, and coordinate disclosure with the reporter. The official 0.8.4 beta app and DMG are Developer ID signed and notarized. Older releases and source/CI community builds can remain ad-hoc signed; check each release’s stated status.

The current threat model and privacy requirements are in [docs/SECURITY.md](docs/SECURITY.md).

