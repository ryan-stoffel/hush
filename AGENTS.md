# AGENTS.md

AGENTS.md and CLAUDE.md carry the same content and must be kept in sync. Any change to this file must be made to CLAUDE.md in the same commit. CLAUDE.md has one extra final section, "Claude Code notes", that this file does not have.

## What this project is

Hush is an open-source macOS menu bar app for voice dictation: hold a key, speak, release, and cleaned-up text is inserted at the cursor in any app, on-device by default. Status as of 2026-09-17: only the skeleton is merged (menu bar agent app shell, demo mode argument parsing, UI test harness, CI); every type named below that is not in `Sources/` yet is planned, and v0.1 is in progress.

Facts: repo https://github.com/ryan-stoffel/hush, maintainer @ryan-stoffel, bundle id `io.github.ryan-stoffel.hush`, MIT, macOS 14+, arm64 and x86_64, Swift tools version 5.10, Xcode 16 or newer (CI uses Xcode 26 on macos-26 runners).

Milestones:

- v0.1: menu bar, hotkey, capture, local transcription, paste insertion.
- v0.2: cleanup, dictionary, history, settings.
- v0.3: snippets, command mode, cloud backends.
- v1.0: onboarding, updater, signed release.

## Architecture map

Target pipeline (planned, lands across v0.1 to v0.3):

```
hotkey down
  -> AudioCaptureService.start          overlay shows waveform and timer
hotkey up
  -> AudioCaptureService.stop           returns AudioBuffer (memory only, never on disk)
  -> TranscriptionBackend.transcribe
  -> CleanupPipeline.run                rules, then optional LLMCleaner
  -> SnippetExpander
  -> InsertionStrategySelector
  -> AccessibilityInserter              falls back to PasteInserter
  -> HistoryStore.append
  -> DictationState back to idle

Command mode (v0.3): second hotkey, reads selected text, speech is the instruction,
LLM returns replacement text, inserted over the selection.
```

Three layers. Dependencies point downward only: App -> HushKit -> HushCore.

`App/` (app target): `main.swift` creates `AppDelegate` and runs `NSApplication` with the `.accessory` activation policy. No logic lives here.

`HushCore` (pure, deterministic, Foundation only, fully unit tested):

- Merged: `AppInfo`, `DemoMode` (parses `-demoMode YES -demoScene <name>`).
- `DictationState`: idle, listening, transcribing, error(message).
- `HotkeyStateMachine`: raw modifier and key events in, pushToTalkStart, pushToTalkEnd, toggle out. Hold mode and hands-free toggle mode.
- `TranscriptionBackend` protocol: `func transcribe(_ audio: AudioBuffer, options: TranscriptionOptions) async throws -> Transcript`. Local and cloud backends conform.
- `CleanupPipeline`: ordered stages. FillerWordRemover, SelfCorrectionParser, SpokenPunctuation, PunctuationAndCapitalization, DictionaryApplier, SnippetExpander, then optional LLMCleaner.
- `LLMCleaner` protocol: same shape as `TranscriptionBackend`. Local and cloud implementations.
- `InsertionStrategySelector`: picks accessibility or clipboardPaste for the frontmost app from bundle id and AX capability probes.
- `HistoryStore`, `DictionaryStore`, `SnippetStore`: local JSON files in Application Support. `SettingsStore` over UserDefaults. `SecretStore` protocol for the Keychain.

`HushKit` (platform: AppKit, SwiftUI, AVFoundation, Accessibility, WhisperKit):

- Merged: `AppDelegate` (holds the parsed `DemoMode`, keeps the app alive with no windows).
- `AppCoordinator` owns the pipeline. `DemoScene` registers scenes and seeded data.
- `StatusItemController` (NSStatusItem, state-driven icon), popover (SwiftUI in NSPopover).
- `FnKeyMonitor` / `EventTapHotkeyMonitor` (CGEventTap on flagsChanged and keyDown).
- `AudioCaptureService` (AVAudioEngine, converts to 16 kHz mono Float32, publishes levels).
- `OverlayPanelController` (non-activating NSPanel, waveform, elapsed time). Must never take focus.
- `WhisperKitBackend` (on-device, default; reports itself unavailable on Intel), later `OpenAIBackend` and `DeepgramBackend` (v0.3).
- `PasteInserter` (clipboard save, write, synthetic Cmd+V, restore), `AccessibilityInserter` (AXUIElement kAXSelectedTextAttribute).
- `PermissionsService`: microphone (capture), Accessibility (synthetic Cmd+V and the AX API), Input Monitoring (the listen-only CGEventTap that sees the Fn key).
- Windows: Settings (tabs), History, Onboarding. SwiftUI hosted in NSWindow.

Longer form: `docs/ARCHITECTURE.md`.

## Where things live

| Path | Contents |
| --- | --- |
| `Package.swift` | SwiftPM manifest: `HushCore`, `HushKit`, and their test targets. Every dependency is justified in a comment. |
| `project.yml` | XcodeGen spec. Generates `Hush.xcodeproj` with the `Hush` app target, the `HushUITests` target, and the `Hush` scheme. |
| `App/` | App target only: `main.swift`, `Info.plist`, `Hush.entitlements`. `Assets.xcassets` arrives with the first icon. |
| `Sources/HushCore/` | Pure logic. |
| `Sources/HushKit/` | Platform code, grouped in subfolders by area (`App/` exists today). |
| `Tests/HushCoreTests/` | Unit tests for Core. |
| `Tests/HushKitTests/` | Unit tests for Kit pieces that run headlessly, using fakes. |
| `UITests/` | XCUITest screenshot suite: `ScreenshotHarness.swift` (base class `ScreenshotTestCase`), `ScreenshotTests.swift`. |
| `scripts/` | `bootstrap.sh`, `lint.sh`, `test.sh`, `capture-screenshots.sh`, `pr_screenshots.py`, `check_pr.py`, `changelog_release.py`, `sign-and-notarize.sh`. |
| `docs/` | `ARCHITECTURE.md`, `RESEARCH.md`, `RELEASING.md`, `MANUAL_TEST.md`. |
| `.github/` | Workflows, issue and PR templates, `CODEOWNERS`, `dependabot.yml`. |

Generated, never committed: `Hush.xcodeproj`, `.build/`, `DerivedData/`, `build/`, `screenshots/`.

Where to add things:

| To add | Put it here | Also required in the same PR |
| --- | --- | --- |
| Demo scene | A case in `DemoScene`, `Sources/HushKit/Demo/` (the folder arrives with the first scene). The scene name equals the screenshot file name, for example `settings-audio`. | Seeded in-memory data with fixed dates. A UI test for the scene. |
| UI test | A `test...` method in `UITests/ScreenshotTests.swift`: `launch(scene: "<name>")`, then `capture(<element>, named: "<name>")`. | The demo scene it launches. |
| Cleanup stage | A type in `Sources/HushCore/` conforming to the pipeline stage protocol, inserted at the right position in `CleanupPipeline`'s ordered stage list. | Table-style unit tests in `Tests/HushCoreTests/`, including the stage's position relative to its neighbors. |
| Transcription or LLM backend | The protocol stays in `Sources/HushCore/`. The conforming type goes in `Sources/HushKit/`. API keys go through `SecretStore`. | A fake-driven test in `Tests/HushKitTests/`. A row in the Settings transcription tab. `docs/MANUAL_TEST.md` steps. |
| Settings tab | A SwiftUI view in `Sources/HushKit/`, registered with the Settings window. Persisted values go through `SettingsStore`. | Scene `settings-<tab>` and its UI test. |
| Store or state machine | `Sources/HushCore/`. | Unit tests in `Tests/HushCoreTests/`. |

Every new window or tab must add a scene and a UI test in the same PR.

## Commands

Run from the repo root.

| Task | Command |
| --- | --- |
| Bootstrap (installs xcodegen, swiftformat, swiftlint with Homebrew if missing, generates the project) | `scripts/bootstrap.sh` |
| Install tools by hand | `brew install xcodegen swiftformat swiftlint` |
| Regenerate the Xcode project | `xcodegen generate` |
| Build headlessly | `xcodebuild -project Hush.xcodeproj -scheme Hush -destination 'platform=macOS' build` |
| Unit tests | `scripts/test.sh unit` (runs `swift test`) |
| UI tests | `scripts/test.sh ui` (regenerates the project, runs `HushUITests`, result bundle at `build/ui-tests.xcresult`) |
| Unit then UI tests | `scripts/test.sh` |
| Lint (check mode, what CI runs) | `scripts/lint.sh` |
| Lint fix | `scripts/lint.sh --fix` |
| Capture screenshots | `scripts/capture-screenshots.sh <source-dir> <output-dir>`, for example `scripts/capture-screenshots.sh . screenshots` |

`DERIVED_DATA_PATH` overrides the DerivedData location for `test.sh` and `capture-screenshots.sh`. Both pass `CODE_SIGN_IDENTITY=-` (ad hoc signing), so no certificate is needed.

UI tests launch the real app and drive the screen. They need a logged-in GUI session and take over the display while they run.

## Conventions

- Swift style is whatever `.swiftformat` and `.swiftlint.yml` produce: 4 spaces, 120 columns, trailing commas, no redundant `self`. SwiftLint runs `--strict`, so warnings fail CI. `force_unwrapping` is an error: use `guard let`, `if let`, or `XCTUnwrap` in tests.
- HushCore imports Foundation only. AppKit, SwiftUI, AVFoundation, network, and third-party imports belong in HushKit.
- Every platform boundary (microphone, event tap, pasteboard, event posting, AX, Keychain, network, clock, file system location) sits behind a protocol. Production types live in HushKit, fakes live in the test targets, and logic is tested through the fakes.
- Plain ASCII in code, comments, commit messages, PR text, and docs. No emojis, no icon characters.
- Comments only where the logic is not obvious. Explain why, not what.
- The dependency list is closed. Pre-approved: WhisperKit (https://github.com/argmaxinc/argmax-oss-swift, product WhisperKit, from 1.1.0), added by the v0.1 transcription issue, and Sparkle (from 2.10.0), added in v1.0 and not before. Anything else needs an issue and maintainer sign-off first. Each entry in `Package.swift` carries a comment that says what it is for and why the SDK cannot do the job.
- Privacy rule: Nothing leaves the machine unless the user picks a cloud backend. With local backends selected the app makes no network requests other than the one-time model download from Hugging Face by WhisperKit and the Sparkle update check (which can be disabled). API keys live only in the Keychain. Audio is never written to disk. History is stored locally and can be cleared or disabled.
- Demo mode (`-demoMode YES -demoScene <name>`) must never touch the microphone, event taps, Accessibility, the Keychain, or the network. It uses seeded in-memory data with fixed dates and opens the named scene immediately. Any code path that reaches one of those services checks `DemoMode` first and gets a fake or a no-op.
- The overlay panel never takes focus. Stealing focus from the target app breaks insertion.
- Update `CHANGELOG.md` under Unreleased for anything user visible.

## Workflow for every change

1. Find the issue, or create one. One issue per PR. Labels: a type (feature, bug, chore, docs), an area, a priority, and the milestone.
2. Branch from an up-to-date `develop`. Name: `<feature|bug|chore|docs>/gh-issue-<number>-<slug>`, matching `^(feature|bug|chore|docs)/gh-issue-[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`. Example: `feature/gh-issue-12-fn-key-monitor`.
3. Implement with tests. Core logic gets unit tests. Kit code gets fake-driven tests where it can run headlessly. New windows and tabs get a demo scene and a UI test.
4. Run `scripts/lint.sh` and `scripts/test.sh`. Fix formatting with `scripts/lint.sh --fix`.
5. Open a PR into `develop` using `.github/PULL_REQUEST_TEMPLATE.md`. Fill every section. Keep the screenshots markers. Write `No UI change` in the Before and After section when that is true.
6. Wait for CI: `lint`, `unit-tests`, `ui-tests`, `branch-name`, `linked-issue`, `pr-format`, `screenshots`. The `screenshots` job rewrites the PR body between the markers. Read the table and confirm the After column shows what you intended.
7. Squash merge into `develop`. The squash commit takes the PR title.

## Branch rules

- `main`: releases only. Protected. Changes arrive only by PR from `develop`, with passing CI and one approving review. Merge commit (no squash).
- `develop`: integration branch. Protected. Requires a PR, passing CI, and a linked issue. Squash merge only.
- Work branches start from `develop` and are named exactly:
  - `feature/gh-issue-<number>-<slug>`
  - `bug/gh-issue-<number>-<slug>`
  - `chore/gh-issue-<number>-<slug>`
  - `docs/gh-issue-<number>-<slug>`
  `<slug>` is lowercase letters, digits, and hyphens. Regex: `^(feature|bug|chore|docs)/gh-issue-[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$`
- Exceptions enforced by CI: a PR into `main` must come from `develop`. Dependabot branches (`dependabot/**`) are exempt from the branch name and linked issue checks.
- The `screenshots` branch is an orphan branch written only by CI. Never commit to it by hand, never merge it.
- The `gh-pages` branch hosts the Sparkle appcast and is written only by the release workflow.

## Pull request rules

1. Title uses Conventional Commits: `type(scope): summary`. Types: feat, fix, chore, docs, refactor, test, ci, build, perf. Scopes: audio, hotkey, transcription, cleanup, insertion, ui, settings, ci, release, docs, deps. Summary is lowercase imperative with no trailing period. The squash commit takes this title.
2. Body must contain `Closes #<number>` or `Fixes #<number>`. CI fails the PR when no issue is linked.
3. Body must contain a `## Before and After` section. CI builds the merge base and the PR head, captures every window with the XCUITest screenshot suite, pushes the images to the `screenshots` branch, and writes a two-column table between the `<!-- screenshots:start -->` and `<!-- screenshots:end -->` markers in the PR body. Do not remove the markers. Images are embedded, never linked as artifacts. A PR that changes no UI must say `No UI change` in that section, and the check accepts that.
4. Tests must pass. Lint must pass. Screenshots must be present or explicitly waived with `No UI change`.
5. Squash merge only into `develop`. Merge commit from `develop` into `main`.
6. One issue per PR. Keep PRs small. Update CHANGELOG.md under Unreleased for anything user visible.

PRs from forks get a read-only token, so the images are uploaded as a workflow artifact and a maintainer re-runs the capture from a branch in the main repo.

## Commit format

Conventional Commits, same types and scopes as PR titles. Small, focused commits. No emojis. No AI attribution or co-author trailers.

Example: `feat(hotkey): add hold mode to the hotkey state machine`

## What not to touch

- The `screenshots` and `gh-pages` branches.
- The `<!-- screenshots:start -->` / `<!-- screenshots:end -->` markers in PR bodies and the template.
- Branch protection, required check names (job names in workflows), and workflow permissions, unless the issue is specifically about CI.
- Package.swift dependencies. No new dependency without an issue and maintainer approval.
- Bundle identifier, signing settings, entitlements, Sparkle keys.
- Never commit the generated .xcodeproj, secrets, API keys, or model files.
- Never push to main or develop directly. Never force push shared branches.

## How to run tests and what cannot be tested automatically

| Layer | Command | Covers |
| --- | --- | --- |
| Unit | `scripts/test.sh unit` | HushCore logic and HushKit pieces behind fakes. Headless. Seconds. |
| UI | `scripts/test.sh ui` | The app launched in demo mode, one scene per test, one PNG attachment per scene. Needs a GUI session. |
| Screenshots | `scripts/capture-screenshots.sh . screenshots` | The same suite, exported to `<scene-name>.png` files. CI runs it on the merge base and the PR head. |
| Manual | `docs/MANUAL_TEST.md` | Everything below. |

Real dictation (microphone, global hotkey, Accessibility insertion) cannot run on a CI runner. It is verified by hand with docs/MANUAL_TEST.md before each release and whenever a PR touches audio, hotkey, transcription, or insertion code.

An agent cannot speak into a microphone or grant TCC permissions. When a PR touches those areas, list the `docs/MANUAL_TEST.md` sections that apply in the PR's Testing section and leave that box unchecked for the human who runs them. Report a manual check as done only when a person ran it and told you the result. The same goes for test runs: report the command and its real outcome, including failures.

## Definition of done

- [ ] The change matches its issue, and only that issue.
- [ ] The branch name matches the regex and starts from `develop`.
- [ ] New logic has unit tests. New windows and tabs have a demo scene and a UI test.
- [ ] `scripts/lint.sh` passes.
- [ ] `scripts/test.sh` passes, or the PR states exactly which half was not run locally and why.
- [ ] HushCore still imports Foundation only. No new dependency.
- [ ] Demo mode still reaches no microphone, event tap, AX, Keychain, or network code.
- [ ] The privacy rule holds: no new network request with local backends selected, no audio on disk, keys only in the Keychain.
- [ ] `CHANGELOG.md` has an Unreleased entry if the change is user visible.
- [ ] The PR title is `type(scope): summary`, the body has `Closes #<number>`, the Before and After section has the markers or `No UI change`.
- [ ] Manual test sections are listed for audio, hotkey, transcription, or insertion changes, and none is claimed without a human result.
- [ ] Docs that describe the changed behavior are updated. AGENTS.md and CLAUDE.md are still in sync.
- [ ] All seven required checks are green and the screenshot table shows the intended result.
