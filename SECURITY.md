# Security Policy

Quoth is a macOS menu bar dictation app. To do its job it needs the microphone, Accessibility, and Input Monitoring permissions, which makes security reports about it worth taking seriously. This document says which versions get fixes, how to report a problem, what counts as a vulnerability, and what the project commits to by design.

Status as of 2026-09-17: only the project skeleton exists (menu bar agent app shell, demo mode argument parsing, UI test harness, CI). No release has been published. The v0.1 features are in progress. The threat model and design commitments below describe the app as specified, and each item names the milestone in which the relevant code lands. Reports against code on `develop` are welcome now.

## Supported versions

Quoth is pre-1.0. Only the latest release and the `develop` branch get security fixes. There are no backports to older releases. If you run an older build, update to the latest release first and check whether the problem is still present.

| Version | Supported |
| --- | --- |
| `develop` branch | Yes |
| Latest release | Yes (no release has been published yet) |
| Any older release | No |

This policy will be revisited at v1.0.

## Reporting a vulnerability

Report privately with GitHub private vulnerability reporting:

https://github.com/ryan-stoffel/quoth/security/advisories/new

You can also reach the form from the repository's Security tab, "Report a vulnerability". Never open a public issue, discussion, or pull request for a suspected vulnerability, and do not describe it in a commit message. The project does not publish a security email address. The advisory form is the only channel.

Include as much of the following as you can:

- The Quoth version or commit hash, and how it was obtained (release download or built from source).
- The macOS version and the Mac's architecture (Apple silicon or Intel).
- The relevant settings: transcription backend (local or cloud), cleanup backend, insertion behavior, whether history is enabled, whether update checks are enabled.
- Which permissions were granted (Microphone, Accessibility, Input Monitoring).
- Steps to reproduce, or a proof of concept.
- What an attacker gains: what data is exposed or what action becomes possible, and what access the attacker needs to start with.
- Logs, packet captures, or file paths that show the problem. Remove your own API keys, transcripts, and clipboard contents before attaching anything.
- Whether you want to be credited in the advisory, and under what name.

Response targets:

| Step | Target |
| --- | --- |
| Acknowledge the report | Within 3 days |
| Initial assessment (accepted or declined, severity, rough plan) | Within 10 days |
| Fix and disclosure | Coordinated with the reporter |

Disclosure is coordinated. The maintainer (@ryan-stoffel) works on the fix in a private fork attached to the advisory, agrees a disclosure date with you, ships the fix in a release, and then publishes the GitHub security advisory with credit unless you ask to stay anonymous. Please do not disclose the issue publicly before that date. If you get no acknowledgement within the target, add a comment on the advisory. Do not move the report to a public channel.

Quoth is maintained by one person in spare time. The targets above are commitments, not guarantees of a fix date. There is no bug bounty.

## Scope and threat model

### What the app holds

Quoth is specified to hold these capabilities. Each one is an asset an attacker would want.

| Capability | Used for | Lands in |
| --- | --- | --- |
| Microphone permission | Capturing speech while the hotkey is held. `AudioCaptureService` converts to 16 kHz mono in memory. | v0.1 |
| Input Monitoring permission | A listen-only `CGEventTap` on `flagsChanged` and `keyDown`, so the app can see the Fn key and the configured hotkeys. The tap observes events. It does not modify or block them. | v0.1 |
| Accessibility permission | Posting the synthetic Cmd+V and using the AX API (`kAXSelectedTextAttribute`) to insert text and, in command mode, to read the selected text. | v0.1 (paste), v0.3 (command mode) |
| Clipboard access | `PasteInserter` saves the clipboard, writes the transcript, pastes, then restores the previous contents. | v0.1 |
| Local history, dictionary, snippets | JSON files in the user's Application Support directory. | v0.2 (history, dictionary), v0.3 (snippets) |
| API keys in the Keychain | Keys for cloud transcription and cloud cleanup backends the user opts into. Stored through the `SecretStore` protocol, only in the Keychain. | v0.3 |
| Auto-update | Sparkle, with an EdDSA signed appcast hosted on the `gh-pages` branch, written only by the release workflow. | v1.0 |
| Demo mode | Launch arguments `-demoMode YES -demoScene <name>` for screenshots and UI tests. In demo mode the app never touches the microphone, event taps, Accessibility, the Keychain, or the network. Argument parsing is merged. Scenes are in progress. | v0.1 onward |

### What counts as a vulnerability

Report any of the following:

- Audio or transcripts leaving the machine while local backends are selected. With local backends the only permitted network requests are the one-time model download from Hugging Face by WhisperKit and the Sparkle update check.
- Audio written to disk, anywhere, in any configuration.
- API keys written outside the Keychain (UserDefaults, JSON files, temporary files, crash reports) or written to logs.
- Keystrokes recorded, stored, or transmitted beyond what hotkey detection needs. The event tap exists to recognize the hotkey. Any buffer, log, or file that retains other key events is a vulnerability.
- The event tap modifying, dropping, or injecting events other than the synthetic Cmd+V used for insertion.
- Clipboard contents leaked (logged, stored in history, sent over the network) or not restored after a paste insertion.
- Update integrity bypass: installing an update that is not signed with the project's EdDSA key, a downgrade attack, or an appcast served from anywhere other than the project's `gh-pages` site.
- History, dictionary, or snippet files readable by other users on the same Mac, or written outside the user's own Application Support directory.
- Demo mode reachable in a way that bypasses permission checks in a release build. Demo mode must only ever reduce what the app touches. If a launch argument, environment variable, or URL can make a release build skip a permission check while still reaching the microphone, event tap, Accessibility, Keychain, or network, that is a vulnerability.
- The overlay panel or any window taking focus in a way that redirects the user's typing or the inserted text to an unintended target.
- Text inserted into an app other than the one that was frontmost when dictation ended, where an attacker can influence the target.
- A request sent to a cloud backend the user did not select, or sent with a key belonging to a different backend.
- Problems in the build and release pipeline that would let someone other than the maintainer publish a release or write to the `gh-pages` or `screenshots` branches, including workflow permission mistakes and script injection through PR titles, bodies, or branch names.

If you are unsure whether something qualifies, report it privately anyway.

### Out of scope

- Attacks that need an already compromised user account or root. An attacker who can run code as the user can already read the user's Application Support files, query the Keychain with the user's consent prompts, and record the screen. Quoth cannot defend against that.
- The behavior of third-party cloud APIs the user opted into. Once the user selects a cloud backend, audio or text is sent to that provider under that provider's terms. Retention, training use, and breaches on the provider's side are outside this project's control. A bug in how Quoth talks to the provider (wrong host, missing TLS validation, key sent to the wrong endpoint) is in scope.
- Social engineering of the user or the maintainer, including convincing a user to grant permissions to a modified build.
- Physical access to an unlocked Mac.
- Unsigned or ad-hoc signed builds being blocked by Gatekeeper. When signing secrets are not configured, the release workflow produces an ad-hoc signed build that is not notarized, and says so in the release notes. That is expected behavior.
- Builds from forks, or builds modified by the person running them.
- Vulnerabilities in macOS, Core ML, or the Keychain itself. Report those to Apple.
- Transcription errors, including misheard words that change the meaning of inserted text. Those are bugs. File a normal issue.
- Denial of service that needs local access, such as filling the disk with history entries.

## Security design commitments

The privacy rule, from the project spec:

> Nothing leaves the machine unless the user picks a cloud backend. With local backends selected the app makes no network requests other than the one-time model download from Hugging Face by WhisperKit and the Sparkle update check (which can be disabled). API keys live only in the Keychain. Audio is never written to disk. History is stored locally and can be cleared or disabled.

Beyond that rule:

- **No telemetry.** No analytics, no crash reporting service, no usage pings. The app has no server of its own to talk to.
- **On-device by default.** The default transcription backend is WhisperKit running locally (v0.1). Cloud backends are opt-in and arrive in v0.3.
- **Listen-only event tap (v0.1).** The keyboard tap will be created listen-only. It cannot alter or swallow the user's keystrokes, and it will keep no record of events that are not part of hotkey detection.
- **Clipboard is restored (v0.1).** Paste insertion will always restore the previous clipboard contents, including on failure paths. The transcript will not be left on the clipboard.
- **Pure logic is isolated.** `QuothCore` is Foundation only: no AppKit, no network. The code that decides what to do with text cannot open a socket. Platform access lives in `QuothKit`.
- **Hardened runtime.** The app target builds with `ENABLE_HARDENED_RUNTIME: YES` (see `project.yml`), and `scripts/sign-and-notarize.sh` signs with `--options runtime`. The only entitlement in `App/Quoth.entitlements` is `com.apple.security.device.audio-input`. There are no exceptions for unsigned executable memory, library validation, or DYLD environment variables. Changes to entitlements need maintainer review.
- **No App Sandbox, and why.** Quoth is not sandboxed and is not distributed through the Mac App Store. Its core function is inserting text into other apps, which needs the Accessibility API and posting synthetic key events to other processes. Neither works from inside the App Sandbox. The hardened runtime, the single entitlement, and the macOS permission prompts (Microphone, Accessibility, Input Monitoring) are the boundaries instead. `PermissionsService` (v0.1) is the single place that checks those grants, and a feature does not run without its grant.
- **Demo mode only removes access.** Demo mode exists so CI can screenshot the UI without permissions. It is specified to use seeded in-memory data and to never touch the microphone, event taps, Accessibility, the Keychain, or the network. Scenes with seeded in-memory data are in progress; only argument parsing is merged. Demo mode must never become a way to reach those with fewer checks.
- **Signed releases and updates.** From v1.0, releases are signed with a Developer ID certificate and notarized, and Sparkle verifies every update against the project's EdDSA public key before installing it. The EdDSA private key and the signing credentials exist only as GitHub Actions secrets used by `release.yml`. They are never committed.
- **CI runs with least privilege.** Pull request workflows use only `GITHUB_TOKEN`. The check workflows (`ci.yml`, `branch-name.yml`, `linked-issue.yml`, `pr-format.yml`) are read-only. The `screenshots` workflow gets `contents: write` and `pull-requests: write` and nothing more. Pull requests from forks get a read-only token. Signing and Sparkle secrets are read only by `release.yml`, which runs on `v*` tags.

## Dependencies

The dependency policy is deliberately strict: two pre-approved third-party dependencies, and nothing else without an issue and maintainer sign-off. Every entry in `Package.swift` carries a comment that justifies it. As of 2026-09-17 the `dependencies` array in `Package.swift` is empty.

| Dependency | Source | Purpose | Lands in |
| --- | --- | --- | --- |
| WhisperKit | https://github.com/argmaxinc/argmax-oss-swift (product `WhisperKit`, from 1.1.0) | On-device Whisper inference with Core ML. It performs the one-time model download from Hugging Face. | v0.1 |
| Sparkle | https://github.com/sparkle-project/Sparkle (from 2.10.0) | Auto-update with an EdDSA signed appcast. | v1.0, not before |

Dependabot (`.github/dependabot.yml`) checks the `swift` and `github-actions` ecosystems weekly and opens pull requests against `develop`. Those pull requests must pass the `lint`, `unit-tests`, and `ui-tests` jobs like any other change. The branch name, linked issue, and PR format checks are skipped for Dependabot, and a maintainer reviews each update before it is merged.

If you find a vulnerability in WhisperKit or Sparkle, report it to that project. If the way Quoth uses the dependency makes the problem exploitable, or a fixed version needs to be pulled in quickly, report it here as well through the private advisory form.
