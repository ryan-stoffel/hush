# Changelog

All notable changes to Quoth are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Add entries under Unreleased in the pull request that makes the change. The release workflow moves them into a versioned section with `scripts/changelog_release.py` when a `v*` tag is pushed, so keep the `## [Unreleased]` heading as it is and keep the link references at the bottom of the file, one per line.

Features are listed only once they are merged. Planned work is tracked in the GitHub milestones.

## [Unreleased]

### Added

- Text insertion by clipboard paste: snapshot, transient-marked write, layout-aware Cmd+V, and restore guarded by the pasteboard change count. (#8)
- Transcription backend protocol and the default on-device WhisperKit backend (model download with progress, language auto-detect, Whisper marker cleanup). Adds the WhisperKit dependency. (#7)
- Floating, non-activating dictation pill with a live waveform, elapsed time, transcribing and error states. Adds the `overlay-listening` and `overlay-transcribing` demo scenes. (#6)
- Microphone capture with AVAudioEngine, resampled to 16 kHz mono Float32 in memory, with input level metering and a 10 minute cap. (#5)
- Global push-to-talk detection: a listen-only event tap and a state machine that reports a bare Fn hold and cancels on taps, Fn shortcuts, and extra modifiers. (#4)
- Permissions service for Microphone, Accessibility, and Input Monitoring with request and open-System-Settings paths. The popover lists missing permissions with a Grant button. Adds the `popover-permissions` demo scene. (#3)
- Status item popover showing the current state, the last dictation with a Copy button, the app version, and Quit. Adds the `popover` demo scene and its screenshot test. (#2)
- Menu bar status item whose icon and accessibility label follow the dictation state (idle, listening, transcribing, error), backed by `DictationState` in `QuothCore` and an observable `AppState` in `QuothKit`. Demo mode accepts `-demoState` to start in a given state. (#1)
- SwiftPM package (`Package.swift`, Swift tools version 5.10, macOS 14 minimum) with two library targets and no third-party dependencies: `QuothCore` for pure Foundation-only logic and `QuothKit` for the platform layer. Unit test targets `QuothCoreTests` and `QuothKitTests`.
- XcodeGen project spec (`project.yml`) that generates `Quoth.xcodeproj` with the `Quoth` app target (bundle id `io.github.ryan-stoffel.quoth`, hardened runtime, ad hoc signing for local builds), the `QuothUITests` UI test target, and a shared `Quoth` scheme. The generated project is not committed.
- Menu bar agent app shell: `App/main.swift` starts `NSApplication` with the accessory activation policy, `Info.plist` sets `LSUIElement`, and `AppDelegate` in `QuothKit` keeps the app running with no windows open. The app has no status item, windows, or dictation features yet.
- Entitlements file with the audio input entitlement, in place for the v0.1 capture work.
- `AppInfo` in `QuothCore`: app name, bundle identifier, repository URL, and a version string read from the bundle.
- Demo mode launch argument parsing in `QuothCore` (`DemoMode`): `-demoMode YES` enables it and `-demoScene <name>` selects one scene. `AppDelegate` reads it at launch. No scenes exist yet.
- XCUITest screenshot harness (`UITests/ScreenshotHarness.swift`): launches the app in demo mode with a fixed English locale and attaches a named PNG per captured element. The first test checks that the app launches in demo mode with no windows.
- Scripts: `bootstrap.sh` (installs XcodeGen, SwiftFormat, and SwiftLint with Homebrew, then generates the project), `lint.sh` (check mode, or `--fix`), `test.sh` (`unit`, `ui`, or both), `capture-screenshots.sh`, `pr_screenshots.py`, `check_pr.py`, `changelog_release.py`, and `sign-and-notarize.sh`.
- Lint configuration: `.swiftformat` and `.swiftlint.yml`. CI runs `swiftformat --lint` and `swiftlint --strict`.
- GitHub Actions workflows:
  - `ci`: jobs `lint`, `unit-tests`, and `ui-tests` on pull requests and on pushes to `develop` and `main`.
  - `branch-name`: enforces `(feature|bug|chore|docs)/gh-issue-<number>-<slug>` for work branches, requires pull requests into `main` to come from `develop`, and exempts Dependabot.
  - `linked-issue`: fails a pull request whose body has no `Closes #<number>` or `Fixes #<number>`. Dependabot pull requests are exempt.
  - `pr-format`: checks the Conventional Commits title and the `## Before and After` section.
  - `screenshots`: builds the merge base and the pull request head, captures every window with the screenshot suite, pushes the images to the `screenshots` branch, and writes the before and after table into the pull request body.
  - `release`: on `v*` tags, builds a universal Release app, signs and notarizes it when the signing secrets exist and skips that step cleanly when they do not, publishes a GitHub release, updates the Sparkle appcast on `gh-pages` when `SPARKLE_ED_PRIVATE_KEY` is configured (skipped otherwise; the app does not include Sparkle until v1.0), and opens a CHANGELOG pull request against `develop`.
- Repository configuration: `CODEOWNERS`, Dependabot updates for Swift packages and GitHub Actions targeting `develop`, and a `.gitignore` that excludes generated projects, build output, and screenshots.
- Issue templates for bugs and features, and a pull request template with the linked issue line and the `## Before and After` section with the screenshot markers.
- Contributor and agent documentation: `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `CLAUDE.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, and `docs/` (`ARCHITECTURE.md`, `RESEARCH.md`, `RELEASING.md`, `MANUAL_TEST.md`).
- MIT license.

[Unreleased]: https://github.com/ryan-stoffel/quoth/commits/develop
