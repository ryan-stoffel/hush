# Quoth

Quoth is an open-source macOS menu bar app for voice dictation. Hold a key, speak, release, and cleaned-up text is inserted at the cursor in any app. Transcription runs on-device by default. There are no accounts, no telemetry, and nothing leaves your Mac unless you choose a cloud backend.

- Platform: macOS 14 or later
- License: MIT
- Maintainer: [@ryan-stoffel](https://github.com/ryan-stoffel)

## Status

As of 2026-09-17 the repository contains the project skeleton only:

- the v0.1 dictation loop: hold Fn, speak, release, and the transcript is pasted at the cursor, transcribed on-device with WhisperKit. It is implemented and unit tested but has not yet been verified by hand on a Mac with all three permissions granted (tracked in issue #10)
- a menu bar status item whose icon follows the dictation state, a popover with the state, missing permissions, the last dictation, and Quit, and a floating pill with a waveform and elapsed time
- not there yet: cleanup, dictionary, history, settings, snippets, command mode, cloud backends, onboarding, updater, signed releases
- demo mode launch argument parsing (`-demoMode YES -demoScene <name>`)
- the XCUITest screenshot harness
- CI: lint, unit tests, UI tests, branch name, linked issue, PR format, and before and after screenshot workflows

Dictation does not work yet. v0.1 is in progress. Nothing below is described as working until it is merged. Each feature is listed with the milestone it lands in.

| Milestone | Contents | State |
| --- | --- | --- |
| v0.1 | Menu bar status item and popover, global hotkey (hold Fn, plus hands-free toggle), audio capture, recording overlay, local transcription with WhisperKit, paste insertion | In progress |
| v0.2 | Rule-based cleanup (filler words, self-corrections, spoken punctuation, capitalization), personal dictionary, history, settings window | Planned |
| v0.3 | Snippets, command mode (speak an instruction to rewrite the selected text), cloud transcription backends (OpenAI, Deepgram), optional LLM cleanup | Planned |
| v1.0 | Onboarding, auto-update with Sparkle, Developer ID signed and notarized release | Planned |

Progress is tracked in [milestones](https://github.com/ryan-stoffel/quoth/milestones) and [issues](https://github.com/ryan-stoffel/quoth/issues).

## Screenshots

Screenshots are not taken by hand. CI launches the app in demo mode with seeded data, captures each window with the XCUITest suite, and publishes the images to the `screenshots` branch under `latest/`.

No window exists yet, so no image has been published. Each link below resolves once the feature it shows is merged.

| Scene | Milestone | Image |
| --- | --- | --- |
| Menu bar popover | v0.1 | ![Menu bar popover](https://raw.githubusercontent.com/ryan-stoffel/quoth/screenshots/latest/popover.png) |
| Recording overlay, listening | v0.1 | ![Recording overlay while listening](https://raw.githubusercontent.com/ryan-stoffel/quoth/screenshots/latest/overlay-listening.png) |
| Settings, General tab | v0.2 | ![Settings window, General tab](https://raw.githubusercontent.com/ryan-stoffel/quoth/screenshots/latest/settings-general.png) |
| History | v0.2 | ![History window](https://raw.githubusercontent.com/ryan-stoffel/quoth/screenshots/latest/history.png) |
| Onboarding, welcome | v1.0 | ![Onboarding welcome screen](https://raw.githubusercontent.com/ryan-stoffel/quoth/screenshots/latest/onboarding-welcome.png) |

## How it works

This is the design that v0.1 through v0.3 implement. See [Status](#status) for what exists today.

Hold Fn, speak, release. Text appears where your cursor is. A hands-free toggle mode (press once to start, once to stop) is planned alongside hold mode in v0.1.

The pipeline has five steps:

1. **Hotkey.** A listen-only event tap sees the Fn key go down and starts a dictation.
2. **Capture.** The microphone is recorded into memory as 16 kHz mono audio. A small overlay that never takes focus shows a waveform and the elapsed time.
3. **Transcribe.** On release, the audio buffer goes to the selected transcription backend. The default is WhisperKit, running on-device.
4. **Clean up.** Ordered rule-based stages remove filler words, apply spoken self-corrections, convert spoken punctuation, fix punctuation and capitalization, apply your dictionary, and expand snippets. An optional LLM pass can run after the rules. (v0.2, snippets and the LLM pass in v0.3)
5. **Insert.** The text is inserted into the frontmost app, through the Accessibility API where the app supports it, otherwise by putting the text on the clipboard, sending a synthetic Cmd+V, and restoring the previous clipboard. v0.1 ships paste insertion. The result is appended to local history (v0.2).

Command mode (v0.3) uses a second hotkey: it reads the selected text, treats your speech as an instruction, and replaces the selection with the LLM's result.

The module layout and the reasoning behind it are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Install

There is no release yet. To run Quoth today, follow [Building from source](#building-from-source). What you get is the skeleton described in [Status](#status).

Once releases exist, install will be:

1. Download `Quoth-<version>.zip` (for example `Quoth-1.0.0.zip`) from [Releases](https://github.com/ryan-stoffel/quoth/releases).
2. Unzip it and move `Quoth.app` to `/Applications`.
3. Open it. Quoth appears in the menu bar, not in the Dock.

The signed and notarized release is a v1.0 goal. The release workflow signs with a Developer ID and notarizes only when the signing secrets are configured, and skips that step otherwise. A build without Developer ID signing is blocked by Gatekeeper on first launch. To allow it, open System Settings, Privacy and Security, scroll to the message about Quoth, and choose Open Anyway.

## Permissions

Quoth will ask for three permissions once the features that need them land (v0.1). Each will be requested only when the feature that needs it is used. None of them are requested by the current skeleton, and demo mode never touches any of them.

| Permission | Why | Without it |
| --- | --- | --- |
| Microphone | Record your voice while the hotkey is held. | No audio can be captured, so dictation cannot start. |
| Accessibility | Post the synthetic Cmd+V that pastes the text, and use the Accessibility API to insert text directly and to read the selection for command mode. | Text cannot be inserted into other apps. |
| Input Monitoring | Run the listen-only event tap that sees the Fn key while another app is focused. The tap observes events and never modifies or blocks them. | The global hotkey does not fire. |

All three are managed in System Settings, Privacy and Security.

## Backends

Backends are swappable. Transcription backends conform to one protocol, LLM cleaners to another.

### Transcription

| Backend | Runs | Milestone | Notes |
| --- | --- | --- | --- |
| WhisperKit | On-device (Core ML) | v0.1, default | Downloads the model once from Hugging Face, then works offline. |
| OpenAI | Cloud | v0.3 | You supply the API key. Stored in the Keychain. |
| Deepgram | Cloud | v0.3 | You supply the API key. Stored in the Keychain. |

Intel Macs: the app builds universal (arm64 and x86_64), but WhisperKit does not support Intel. On an Intel Mac the local backend reports itself unavailable, so dictation there requires a cloud backend, which arrives in v0.3.

### Cleanup

| Stage | Runs | Milestone | Notes |
| --- | --- | --- | --- |
| Rule-based pipeline | Always local | v0.2 | Deterministic. No model, no network. |
| LLM cleanup, local | On-device | v0.3, optional | Apple Foundation Models on macOS 26 or later, or any OpenAI-compatible server on localhost. |
| LLM cleanup, cloud | Cloud | v0.3, optional | Off unless you enable it and supply a key. |

The rule-based pipeline always runs. The LLM pass is optional and off by default.

## Privacy

These are the rules every milestone is built to. The current skeleton makes no network requests and stores nothing. See [Status](#status).

Nothing leaves the machine unless you pick a cloud backend.

With local backends selected, the only network requests the app makes are:

1. A one-time model download from Hugging Face, made by WhisperKit the first time the local backend is used.
2. An update check, once Sparkle lands in v1.0. It can be turned off.

The rest of the rules:

- If you select a cloud backend, your audio (transcription) or transcript text (LLM cleanup) is sent to the provider you chose, with your key, and nowhere else.
- API keys are stored only in the macOS Keychain (v0.3, with the cloud backends). They are never written to preferences, files, or logs.
- Audio is never written to disk. It is held in memory for the length of one dictation.
- History (v0.2) is stored locally in Application Support. It can be cleared or disabled.
- No telemetry. No analytics. No accounts.

To report a privacy or security problem, see [SECURITY.md](SECURITY.md).

## Building from source

Requirements:

- macOS 14 or later
- Xcode 16 or newer (CI uses Xcode 26 on `macos-26` runners)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), [SwiftFormat](https://github.com/nicklockwood/SwiftFormat), and [SwiftLint](https://github.com/realm/SwiftLint). `scripts/bootstrap.sh` installs any that are missing with Homebrew. To install them yourself: `brew install xcodegen swiftformat swiftlint`.

Get the source and generate the Xcode project:

```sh
git clone https://github.com/ryan-stoffel/quoth.git
cd quoth
scripts/bootstrap.sh
```

`Quoth.xcodeproj` is generated from `project.yml` and is not committed. Run `xcodegen generate` again after adding, moving, or removing files.

Build and run from Xcode:

```sh
open Quoth.xcodeproj
```

Select the `Quoth` scheme and run. Grant Microphone, Accessibility, and Input Monitoring when asked (the popover lists what is missing), then hold Fn and speak. Quit from the popover.

Or build headless:

```sh
xcodebuild -project Quoth.xcodeproj -scheme Quoth -destination 'platform=macOS' build
```

Run the tests:

```sh
scripts/test.sh          # unit tests, then UI tests
scripts/test.sh unit     # swift test only
scripts/test.sh ui       # XCUITest screenshot suite only
```

The UI tests launch the app in demo mode, so they need no permissions, no microphone, and no network.

Run the linters:

```sh
scripts/lint.sh          # SwiftFormat and SwiftLint in check mode
scripts/lint.sh --fix    # format and autocorrect, then check
```

The library code is a Swift package (tools version 5.10) with two targets: `QuothCore` (pure logic, Foundation only) and `QuothKit` (AppKit, SwiftUI, AVFoundation, Accessibility). The app target in `App/` is a thin entry point. The package currently has no third-party dependencies. WhisperKit is added by the v0.1 transcription work and Sparkle in v1.0.

## Troubleshooting

These apply once the hotkey and insertion features land in v0.1. They are listed now because they are properties of macOS, not of Quoth.

**Holding Fn opens the emoji picker, switches input source, or starts Apple dictation.** macOS assigns an action to the Globe key. Open System Settings, Keyboard, and set "Press Globe key to" to "Do Nothing".

**My external keyboard has no Fn key, or its Fn key does nothing.** Most third-party keyboards handle Fn in firmware and never send it to macOS. Apple keyboards do send it. On other keyboards, choose a different hotkey in Settings (v0.2), or use the built-in keyboard.

**Permissions look granted but the hotkey or insertion does not work.** Reset Quoth's entries and grant them again:

```sh
tccutil reset All io.github.ryan-stoffel.quoth
```

Then quit and reopen Quoth.

**Permissions disappear every time I rebuild.** Builds from source are ad-hoc signed (`CODE_SIGN_IDENTITY` is `-`). macOS ties a permission grant to the code signature, and an ad-hoc signature changes with every build, so a rebuilt app is treated as a different app and loses its grants. Run the `tccutil` command above and grant the permissions again. Signed releases do not have this problem.

**The first dictation is slow.** The local backend downloads its model on first use and Core ML compiles it for your hardware. Later dictations skip both steps.

## Contributing

Issues and pull requests are welcome. Read these first:

- [CONTRIBUTING.md](CONTRIBUTING.md): branching model, pull request rules, how CI produces the before and after screenshots
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md): how to report a vulnerability privately
- [AGENTS.md](AGENTS.md): rules for AI coding agents working in this repo

The short version: every change starts from an issue, work branches start from `develop` and are named `feature/gh-issue-<number>-<slug>`, `bug/gh-issue-<number>-<slug>`, `chore/gh-issue-<number>-<slug>`, or `docs/gh-issue-<number>-<slug>`, and every PR needs a Conventional Commits title, a `Closes #<number>` or `Fixes #<number>` line, and a `## Before and After` section.

## License

MIT. Copyright 2026 Ryan Stoffel. See [LICENSE](LICENSE).
