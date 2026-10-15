# Project requirements

- Preserve the deadline agenda layout and last-known-good cache unless the user explicitly requests a change.
- The user does not accept repeated Keychain approval dialogs. Never run interactive credential probes, repeatedly read the secret during tests, or use the app's changing ad-hoc identity to prompt during refresh. Share the cached credential read, keep Keychain interaction disabled, and retain saved content when silent access fails. Never print or commit a token.
- Keep real academic records, feedback PDFs, API evidence and application-support data outside this public repository. Tests use synthetic fixtures.
- Use native SwiftUI controls, semantic typography/colours and system accent. Document actual visual/accessibility verification rather than claiming blanket HIG certification.
