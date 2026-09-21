# Contributing to Hush

Hush is an open-source macOS menu bar app for voice dictation. This document covers everything you need to land a change: setup, branch and commit rules, what CI checks, and how to test.

Project status as of 2026-09-17: only the skeleton is merged. That means the menu bar agent app shell, demo mode argument parsing, the UI test harness, and CI. The v0.1 features (menu bar, hotkey, capture, local transcription, paste insertion) are in progress. Where this document describes something that is planned rather than merged, it says so and names the milestone.

## Ground rules

- **Issue first.** Every change starts from a GitHub issue. If there is no issue for what you want to do, open one and wait for the maintainer to confirm the direction before you write code. Questions and rough ideas go to [Discussions](https://github.com/ryan-stoffel/hush/discussions). Blank issues are disabled, so use the feature or bug template.
- **One issue per PR.** A pull request closes exactly one issue. If you find a second problem while working, open a second issue.
- **Privacy rule.** Nothing leaves the machine unless the user picks a cloud backend. With local backends selected the app makes no network requests other than the one-time model download from Hugging Face by WhisperKit and the Sparkle update check (which can be disabled). API keys live only in the Keychain. Audio is never written to disk. History is stored locally and can be cleared or disabled. A PR that breaks this rule will not be merged, whatever else it does. That includes analytics, crash reporters, remote logging, and debug code that writes audio to a file.
- **No new dependencies without approval.** `Package.swift` has no third-party dependencies today. Two are pre-approved: WhisperKit (added by the v0.1 transcription issue) and Sparkle (added in the v1.0 milestone, not before). Anything else needs its own issue and maintainer sign-off before the PR is opened. Every entry in `dependencies` carries a comment that says what it is for and why the SDK cannot do the job.
- Be civil. The [Code of Conduct](CODE_OF_CONDUCT.md) applies everywhere in the project.

## Dev setup

Requirements:

- macOS 14 or newer.
- Xcode 16 or newer. CI uses Xcode 26 on `macos-26` runners, so a build that only works on an older Xcode will fail there.
- Swift tools version 5.10 (set in `Package.swift`).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), [SwiftFormat](https://github.com/nicklockwood/SwiftFormat), and [SwiftLint](https://github.com/realm/SwiftLint).

Fork the repository, check out your fork, and run:

```sh
scripts/bootstrap.sh
```

The script installs `xcodegen`, `swiftformat`, and `swiftlint` with Homebrew if any of them is missing, then runs `xcodegen generate`. If a tool is missing and Homebrew is not installed, it stops and tells you which tool to install. To install the tools yourself:

```sh
brew install xcodegen swiftformat swiftlint
```

`Hush.xcodeproj` is generated from `project.yml` and is not committed. `.gitignore` excludes it. Regenerate it whenever you pull, switch branches, add or remove files under `App/` or `UITests/`, or edit `project.yml`:

```sh
xcodegen generate
```

Then open `Hush.xcodeproj` and run the `Hush` scheme, or build headlessly:

```sh
xcodebuild -project Hush.xcodeproj -scheme Hush -destination 'platform=macOS' build
```

Project settings changes go in `project.yml`, never in the Xcode project editor, because the generated project is thrown away. The library targets under `Sources/` are defined in `Package.swift` and the Xcode project consumes them as a local package, so adding a Swift file under `Sources/` or `Tests/` needs no regeneration.

Also generated and never committed: `.build/`, `DerivedData/`, `build/`, `screenshots/`.

The app is ad-hoc signed for local builds (`CODE_SIGN_IDENTITY` is `-`). You do not need a developer account.

## Project layout

```
Package.swift            SwiftPM manifest. Library targets and unit tests.
project.yml              XcodeGen spec. Generates Hush.xcodeproj with the app target and the UI test target.
App/                     App target sources only: main.swift, Info.plist, Hush.entitlements, and later Assets.xcassets.
Sources/HushCore/       Pure Swift logic. Foundation only. No AppKit, no SwiftUI, no network. Fully unit tested.
Sources/HushKit/        Platform layer: AppKit, SwiftUI, AVFoundation, Accessibility. App delegate, coordinators, windows.
Tests/HushCoreTests/    Unit tests for Core.
Tests/HushKitTests/     Unit tests for Kit pieces that can run headlessly.
UITests/                 XCUITest screenshot suite. Launches the app in demo mode.
scripts/                 bootstrap, lint, test, screenshot capture, PR checks, release tooling.
docs/                    ARCHITECTURE.md, RESEARCH.md, RELEASING.md, MANUAL_TEST.md.
.github/                 Workflows, issue and PR templates, CODEOWNERS, dependabot.yml.
```

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the modules, the dictation pipeline, and where each planned type lives.

## Branch naming

The branching model:

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

Valid names:

```
feature/gh-issue-12-fn-key-push-to-talk
bug/gh-issue-47-overlay-steals-focus
chore/gh-issue-31-cache-derived-data
docs/gh-issue-58-manual-test-checklist
```

Names the check rejects:

```
feature/12-fn-key                     no gh-issue- prefix
fix/gh-issue-47-overlay               fix is not an allowed prefix, use bug
feature/gh-issue-12-Fn_Key            uppercase and underscore in the slug
feature/gh-issue-12-                  empty slug
gh-issue-12-fn-key                    no type prefix
```

The number is the issue the PR closes. Start the branch from an up-to-date `develop`:

```sh
git remote add upstream https://github.com/ryan-stoffel/hush.git   # once per checkout
git fetch upstream
git switch -c feature/gh-issue-12-fn-key-push-to-talk --no-track upstream/develop
git push -u origin feature/gh-issue-12-fn-key-push-to-talk
```

In a fork checkout `origin` is your fork, and its `develop` goes stale. `upstream` is the main repository, so the branch starts from the real `develop`. `--no-track` keeps the new branch from tracking `upstream/develop`, and `git push -u origin` makes your fork's branch the push target.

## Commit format

Commits use [Conventional Commits](https://www.conventionalcommits.org/), with the same types and scopes as PR titles:

```
type(scope): summary
```

- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`, `perf`.
- Scopes: `audio`, `hotkey`, `transcription`, `cleanup`, `insertion`, `ui`, `settings`, `ci`, `release`, `docs`, `deps`.
- The summary is lowercase imperative with no trailing period.

Examples:

```
feat(hotkey): add hold mode to the hotkey state machine
fix(insertion): restore the pasteboard after a failed paste
test(cleanup): cover nested self corrections
refactor(audio): move level metering out of the capture service
ci(ci): cache derived data between ui test runs
docs(docs): describe the insertion fallback order
chore(deps): bump actions/checkout to v5
```

Keep commits small and focused. No emojis. No AI attribution or co-author trailers: no `Co-Authored-By` lines for tools, no "generated with" footers. If a tool adds one, remove it before you push.

Work branches are squash merged, so the PR title is what ends up in the history of `develop`. Commit messages on the branch still matter to the reviewer.

## Pull request rules

1. Title uses Conventional Commits: `type(scope): summary`. Types: feat, fix, chore, docs, refactor, test, ci, build, perf. Scopes: audio, hotkey, transcription, cleanup, insertion, ui, settings, ci, release, docs, deps. Summary is lowercase imperative with no trailing period. The squash commit takes this title.
2. Body must contain `Closes #<number>` or `Fixes #<number>`. CI fails the PR when no issue is linked.
3. Body must contain a `## Before and After` section. CI builds the merge base and the PR head, captures every window with the XCUITest screenshot suite, pushes the images to the `screenshots` branch, and writes a two-column table between the `<!-- screenshots:start -->` and `<!-- screenshots:end -->` markers in the PR body. Do not remove the markers. Images are embedded, never linked as artifacts. A PR that changes no UI must say `No UI change` in that section, and the check accepts that.
4. Tests must pass. Lint must pass. Screenshots must be present or explicitly waived with `No UI change`.
5. Squash merge only into `develop`. Merge commit from `develop` into `main`.
6. One issue per PR. Keep PRs small. Update CHANGELOG.md under Unreleased for anything user visible.

### The PR template

GitHub fills the PR body from `.github/PULL_REQUEST_TEMPLATE.md`. It has these parts, in order:

- A hidden comment that repeats the title format, types, scopes, and branch format.
- `Closes #`. Put the issue number after the `#`. The reference must be outside an HTML comment, because the check strips comments before it looks.
- `## Summary`. What changed and why, in a few sentences.
- `## Before and After`. An instruction comment, then the two marker lines.
- `## Testing`. Checkboxes for `scripts/lint.sh`, `scripts/test.sh unit`, `scripts/test.sh ui`, and the relevant sections of `docs/MANUAL_TEST.md`. Add the commands you ran and what you checked by hand.
- `## Checklist`. Branch name, title, exactly one linked issue, a demo scene and screenshot test for new windows or tabs, no unapproved dependency, the privacy rule, the CHANGELOG entry, and AGENTS.md and CLAUDE.md kept in sync if either changed.

### How the screenshot markers work

The template contains this block:

```
<!-- screenshots:start -->
<!-- screenshots:end -->
```

Leave both lines exactly as they are. The `screenshots` workflow replaces everything from the start marker to the end marker with the two markers wrapped around a fresh table. It does this on every push to the PR, so the table always reflects the latest commit and anything you type between the markers is overwritten. Text outside the markers is never touched.

The table has a `Before` and an `After` column and one row per scene name. A scene that exists only on the PR head shows `New` in the Before column. A scene that exists only on the merge base shows `Removed` in the After column. When the two PNG files are byte-identical, the After cell is labelled `(identical)`. If the suite produced no images at all, the block contains a single sentence saying so.

If the PR changes no UI, replace the instruction comment in the section with the words `No UI change` and keep the markers. The workflow still runs and still writes the table. The waiver means the check passes even when no image is embedded.

If the suite produces no images and the section does not say `No UI change`, step 10 of the workflow fails the `screenshots` check. No scenes exist today, so the suite produces no images. Until the first window lands, every PR needs `No UI change` in the section before it is opened.

The `screenshots` workflow does not run on `edited`. If you add `No UI change` after the job failed, push a commit (an empty one works: `git commit --allow-empty`) or ask the maintainer to re-run the job.

If the markers are missing when the workflow runs, it appends a new `## Before and After` section with markers and the table at the end of the body. Do not rely on that. Keep the template structure.

## How CI works

All workflows live in `.github/workflows/`. macOS jobs run on `macos-26` with Xcode 26. The three PR metadata checks run on `ubuntu-latest`.

Required checks on `develop` and `main`: `lint`, `unit-tests`, `ui-tests`, `branch-name`, `linked-issue`, `pr-format`, `screenshots`. These are job names. Branch protection refers to them by name, so do not rename a job unless the issue is specifically about CI.

### ci.yml

Runs on every pull request and on pushes to `develop` and `main`. A new push to the same PR cancels the run in progress. The token is read-only.

| Job | What it does | What makes it fail |
| --- | --- | --- |
| `lint` | Installs SwiftFormat and SwiftLint if missing, then runs `scripts/lint.sh`, which runs `swiftformat --lint` and `swiftlint lint --strict` over `Package.swift`, `App`, `Sources`, `Tests`, and `UITests`. | Any file SwiftFormat would change. Any SwiftLint violation, because `--strict` turns warnings into errors. |
| `unit-tests` | Prints the toolchain versions, runs `swift build --build-tests`, then `swift test --skip-build`. | A compile error in any library or test target, or a failing unit test. |
| `ui-tests` | Installs XcodeGen, runs `xcodegen generate`, builds the `Hush` scheme headlessly with `xcodebuild build`, then runs `scripts/test.sh ui`, which runs the `HushUITests` bundle and writes `build/ui-tests.xcresult`. | An invalid `project.yml`, a build error in the app or UI test target, or a failing UI test. For the screenshot suite that usually means a scene did not appear within 15 seconds. |

When `ui-tests` fails, the result bundle is uploaded as the `ui-tests-xcresult` artifact and kept for 7 days. Download it and open it in Xcode to see the failure and its screenshots.

Caching: `unit-tests` caches `.build` and `~/Library/Caches/org.swift.swiftpm`, keyed on the hash of `Package.swift` and `Package.resolved`. `ui-tests` caches `DerivedData` and the SwiftPM cache, keyed on the hash of `Package.swift`, `Package.resolved`, and `project.yml` plus the commit SHA, with restore keys that fall back to the newest cache for the same manifests and then to any cache for the same runner. The job sets `IgnoreFileSystemDeviceInodeChanges` for the Xcode build system so that a restored `DerivedData` still counts as an incremental build.

### branch-name.yml

Job `branch-name`. Runs when a PR is opened, reopened, pushed to, or edited. It checks the head branch against the regex in [Branch naming](#branch-naming).

- A PR into `main` passes only when the head branch is `develop`.
- A PR opened by `dependabot[bot]` is skipped.
- Anything else must match the regex, or the job fails and prints the four allowed patterns.

A branch cannot be renamed on an open PR. If this check fails, push the commits to a correctly named branch and open a new PR.

### linked-issue.yml

Job `linked-issue`. Same triggers. It reads the PR body through the API and runs `scripts/check_pr.py linked-issue`. It fails when the body, with HTML comments removed, contains no `Closes #<number>` or `Fixes #<number>` (case-insensitive). Dependabot PRs are skipped.

### pr-format.yml

Job `pr-format`. Same triggers. Dependabot PRs are skipped. It runs two checks from `scripts/check_pr.py`:

- `title`: the title must match `type(scope): summary` with a type and scope from the lists above. It fails when the summary starts with an uppercase letter or ends with a period.
- `before-after`: the body must have a `## Before and After` heading. The section passes when it contains an embedded image, or the words `No UI change`, or both markers (which means the screenshots workflow has not filled them in yet). It fails when the heading is missing, or when the section has no images, no waiver, and no markers.

Because these three workflows run on `edited`, fixing the title or body re-runs them. You do not need to push a commit. This does not apply to `screenshots`, which does not run on `edited` (see below).

### screenshots.yml

Job `screenshots`. Runs when a PR is opened, reopened, pushed to, or marked ready for review. One run per PR at a time. A newer push cancels the older run. It uses only `GITHUB_TOKEN`, with `contents: write` and `pull-requests: write`. There are no personal tokens or extra secrets.

Step by step:

1. Check out the PR head with full history into `head/`.
2. Install XcodeGen if missing.
3. Fetch the base branch, compute the merge base of the base branch and the PR head, and add a detached worktree of that commit at `base/`.
4. Restore the cache: `derived-base`, `derived-head`, and the SwiftPM cache.
5. Capture "before": run the PR head's copy of `scripts/capture-screenshots.sh` against `base/` and write to `shots/before`. The script always comes from the PR head, so a base commit that predates the script or has a broken suite still yields a table. A failure here is a warning, not an error. Before images may then be missing.
6. Capture "after": run the same script against `head/` and write to `shots/after`. A failure here fails the job.
7. Upload `shots/` as the workflow artifact `screenshots-pr-<number>`, kept for 14 days. This happens for every PR, including forks.
8. Push the images to the `screenshots` branch. The job checks out the branch at depth 1, or creates it as an orphan branch with a short README if it does not exist yet. It deletes `pr-<number>/`, copies in the new `before` and `after` folders, commits as `github-actions[bot]`, and pushes. If another run pushed first, it retries up to five times with a growing delay, starting from a fresh checkout each time.
9. Build the table with `scripts/pr_screenshots.py table`, read the current PR body through the API, splice the table between the markers with `scripts/pr_screenshots.py splice`, and PATCH the PR body. The table is also written to the run summary.
10. Verify: read the body back and run `scripts/check_pr.py before-after --require-images`. With that flag, empty markers no longer pass. The section must contain an embedded image or `No UI change`. Otherwise the job fails.

The workflow does not run on `edited`, so fixing the PR body does not re-run it. If you add `No UI change` after the job failed, push a commit (an empty one works: `git commit --allow-empty`) or ask the maintainer to re-run the job.

Layout of the `screenshots` branch:

```
README.md
pr-<number>/before/<scene>.png
pr-<number>/after/<scene>.png
latest/<scene>.png
```

For example `pr-64/before/settings-general.png` and `pr-64/after/settings-general.png`. File names are scene names (see [Demo mode](#demo-mode-and-adding-a-screenshot-scene)).

Image URLs in the table are pinned to the commit on the `screenshots` branch that the run just pushed, not to the branch name:

```
https://raw.githubusercontent.com/ryan-stoffel/hush/<screenshots-commit-sha>/pr-<number>/after/<scene>.png
```

Pinning matters for two reasons. The folder for a PR is replaced on every push, so a branch URL would change under the reader. And a commit URL is immutable, so browsers and GitHub's image proxy can never serve a stale image for it. The table in a merged PR keeps showing exactly what was reviewed.

CI edits your PR body. That is expected. Edits made with `GITHUB_TOKEN` do not trigger workflows, so the body edit does not start another round of `branch-name`, `linked-issue`, `pr-format`, or `screenshots`, and there is no loop. The side effect is that those checks do not re-run after the table is written. That is why the screenshots job runs the stricter `--require-images` check itself in step 10.

Fork limitation: pull requests from forks get a read-only token, so steps 8 to 10 are skipped. The job cannot push to the `screenshots` branch or edit the PR body. The images are still uploaded as the workflow artifact, and the job prints a warning. A maintainer then pushes your commits to a branch in the main repository and re-runs the capture from there, so that the table can be embedded. You do not need to do anything except keep the markers in place.

Dependabot limitation: Dependabot PRs also run with a read-only token, even though their branch is in the main repository. The workflow has no Dependabot skip, so step 8 cannot push and the `screenshots` check fails on those PRs. The maintainer handles them by pushing the update to a `chore/gh-issue-<number>-<slug>` branch and opening a normal PR from it.

A second job in the same workflow, `latest`, runs on pushes to `develop`. It captures the suite once and publishes the images to `latest/` on the `screenshots` branch, skipping the commit when nothing changed. The README links to those images. It is not a required check.

### release.yml

Runs on tags that match `v*`. It archives a universal (arm64 and x86_64) Release build, signs with Developer ID and notarizes when the signing secrets exist and skips that cleanly when they do not, zips the app, creates the GitHub release, updates the Sparkle appcast on `gh-pages` when the Sparkle key exists, and opens a CHANGELOG pull request against `develop`. Contributors never trigger it. See [docs/RELEASING.md](docs/RELEASING.md).

### Dependabot

Dependabot opens weekly PRs against `develop` for Swift packages and GitHub Actions, with `chore(deps)` and `chore(ci)` title prefixes. Those PRs are exempt from the branch name, linked issue, and PR format checks. They do not pass `screenshots` (see the Dependabot limitation under [screenshots.yml](#screenshotsyml)), so the maintainer lands each update from a `chore/gh-issue-<number>-<slug>` branch instead of merging the Dependabot PR directly.

## Running tests locally

Run the same things CI runs before you push.

```sh
scripts/lint.sh              # SwiftFormat and SwiftLint in check mode, same as the lint job
scripts/lint.sh --fix        # rewrite files with SwiftFormat and swiftlint --fix, then check again

scripts/test.sh unit         # swift test
scripts/test.sh ui           # xcodegen generate, then the XCUITest screenshot suite
scripts/test.sh all          # unit, then ui (the default when no argument is given)

scripts/capture-screenshots.sh . /tmp/shots
```

`scripts/test.sh ui` writes its result bundle to `build/ui-tests.xcresult`. Both UI scripts put build products in `./DerivedData` unless `DERIVED_DATA_PATH` is set.

`scripts/capture-screenshots.sh <source-dir> <output-dir>` builds the app found at `<source-dir>`, runs the screenshot suite, exports the attachments from the result bundle, and writes one `<scene>.png` per captured scene into `<output-dir>`. It is exactly what the `screenshots` workflow runs, so it is the fastest way to see what CI will put in your PR. If `<source-dir>` has no `project.yml` or no `UITests` directory, it exits successfully with nothing captured. If the tests fail, it still exports whatever was captured, prints the tail of the xcodebuild log, and exits with xcodebuild's status.

Things to know about the UI tests:

- They need a logged-in GUI session. XCUITest launches the real app and drives it through the window server, so they do not work over plain SSH or on a machine sitting at the login window.
- They take over the screen briefly. The test runner launches and terminates Hush once per test and windows appear and disappear. Do not type or click while they run, because stray input can land in the app under test or steal focus from it.
- The first run asks macOS for permission to let Xcode automation control the computer. You will see a prompt to enable UI automation (it may ask for your password), and possibly an Accessibility prompt for Xcode's test runner. Approve it once. Until you do, the tests fail at launch.
- They never need microphone, Accessibility, or Input Monitoring permission for Hush itself, because the app runs in demo mode.

The unit tests have no such requirements. `swift test` runs anywhere.

## Demo mode and adding a screenshot scene

The app accepts launch arguments `-demoMode YES -demoScene <name>`. In demo mode it never touches the microphone, event taps, Accessibility, the Keychain, or the network, uses seeded in-memory data with fixed dates, and opens the named scene immediately. Scene names equal screenshot file names.

What is merged today: `DemoMode` in `Sources/HushCore/DemoMode.swift` parses the two arguments. `-demoMode` accepts `YES`, `true`, or `1` in any letter case. `-demoScene` is ignored unless demo mode is on. `AppDelegate` reads the parsed value at launch. `UITests/ScreenshotHarness.swift` provides the `ScreenshotTestCase` base class, and the only test so far, `testLaunchesInDemoModeWithoutWindows`, checks that the agent app launches in demo mode and opens no window. No scenes exist yet. They arrive with the windows they show.

Scenes are registered in `DemoScene` (`Sources/HushKit/Demo/`). That type is created by the first PR that adds a window. Planned scenes: `popover`, `overlay-listening`, `overlay-transcribing` (v0.1), `settings-general`, `settings-hotkeys`, `settings-audio`, `settings-transcription`, `settings-cleanup`, `settings-dictionary`, `settings-snippets`, `settings-privacy`, `history` (v0.2 and v0.3, with the tab they show), `onboarding-welcome`, `onboarding-microphone`, `onboarding-accessibility` (v1.0).

The rule: every new window or tab must add a scene and a UI test in the same PR. Without that, the Before and After table cannot show your change and the reviewer cannot see it.

To add a scene:

1. Pick a lowercase, hyphenated name. It becomes the PNG file name, so follow the existing pattern: `<window>` or `<window>-<tab-or-state>`.
2. Add a case for it to `DemoScene` in `Sources/HushKit/Demo/` and make the app open that window, tab, or state at launch when the scene is requested. Feed it seeded in-memory data with fixed dates. Do not read the clock, the user's real settings, or anything else that changes between runs, or the before and after images will differ for no reason.
3. Keep the demo guarantees. The scene must not start audio capture, install an event tap, call the Accessibility API, read the Keychain, or make a network request.
4. Give the root view of the window an accessibility identifier so the test can find it.
5. Add a test to `UITests/ScreenshotTests.swift`:

   ```swift
   func testSettingsGeneral() {
       launch(scene: "settings-general")
       capture(app.windows["settings"], named: "settings-general")
   }
   ```

   `launch(scene:)` starts the app with the demo arguments and an `en_US` locale. `capture(_:named:)` waits up to 15 seconds for the element, fails the test if it never appears, and attaches a screenshot of that element. The `named:` value must equal the scene name, because the capture script turns attachment names into file names.
6. Run `scripts/capture-screenshots.sh . /tmp/shots` and look at the PNG.

If you remove or rename a window, remove or rename its scene and test in the same PR. The table will show the old name as `Removed` and the new one as `New`.

## Manual testing

Real dictation cannot be tested on a CI runner. Runners have no microphone input, no Accessibility or Input Monitoring grants for the app, and no Neural Engine. So the microphone, the global hotkey, on-device transcription, and insertion into other apps are never exercised by CI, and a green check says nothing about them.

They are checked by hand with the checklist in [docs/MANUAL_TEST.md](docs/MANUAL_TEST.md):

- whenever a PR touches audio, hotkey, transcription, or insertion code, and
- before every release.

If your PR touches one of those areas, run the matching sections of the checklist on your own Mac and say in the `## Testing` section of the PR which sections you ran, on which macOS version and hardware, and what you saw. The reviewer repeats them before merging. Logic that can be separated from the hardware (the hotkey state machine, the cleanup stages, strategy selection) belongs in `HushCore` with unit tests, so that the hand-tested surface stays small.

## Merging

- Work branches are squash merged into `develop`. The squash commit takes the PR title, which is why the title format is enforced. Squash is the only merge method allowed on `develop`.
- `develop` is merged into `main` with a merge commit (no squash), by a PR from `develop`, with passing CI and one approving review. This happens only as part of a release.
- Only the maintainer, @ryan-stoffel, merges. `.github/CODEOWNERS` makes the maintainer the required reviewer for every path. Contributors do not get push access to `develop` or `main`, and nobody pushes to either branch directly or force pushes a shared branch.
- A PR is ready to merge when all seven required checks are green, the review is approved, and the manual checklist has been run where it applies.
- If `develop` moves while your PR is open, run `git fetch upstream` and merge `upstream/develop` into your branch or rebase onto it. Force pushing your own work branch is fine.

## Releases

Releases are cut by the maintainer from `main` by pushing a `v*` tag. The process, the signing and notarization secrets, the appcast, and the CHANGELOG pull request are described in [docs/RELEASING.md](docs/RELEASING.md). Your part as a contributor is rule 6: add a line to `CHANGELOG.md` under Unreleased for anything user visible.

## Code style

- **SwiftFormat** is configured in `.swiftformat`: Swift 5.10, 4-space indent, 120 column maximum width, arguments, parameters, and collections wrapped before the first element, trailing commas always, redundant `self` removed, file headers stripped, `@testable` imports grouped last. Run `scripts/lint.sh --fix` and let the tool decide. Do not argue with the formatter in review.
- **SwiftLint** is configured in `.swiftlint.yml` and runs with `--strict` in CI, so warnings fail the build. Notable settings: `force_unwrapping` is an error, line length warns at 120 and errors at 160, function bodies warn at 60 lines, files warn at 500 lines, cyclomatic complexity warns at 12. Several opt-in rules are on, including `empty_count`, `first_where`, `implicit_return`, `modifier_order`, and `fatal_error_message`. Do not add `swiftlint:disable` comments without saying why in the PR.
- **Comments** only where the logic is not obvious. Explain why, not what. No commented-out code, no banner comments, no file headers. A doc comment on a public type that states a contract (as on `DemoMode`) is welcome.
- **Core stays Foundation-only.** `Sources/HushCore` imports Foundation and nothing else: no AppKit, no SwiftUI, no AVFoundation, no network. Anything that touches the platform goes in `Sources/HushKit` behind a protocol that Core defines, so that Core stays deterministic and fully unit tested. New logic in Core comes with unit tests in the same PR.
- `App/` holds only `main.swift`, `Info.plist`, the entitlements, and (once added) the asset catalog. App behavior lives in `HushKit`.
- The overlay panel must never take focus, and nothing in the app may activate it over the frontmost app during dictation. Insertion depends on that.
- No emojis or icon characters in code, comments, commit messages, or docs.
- Do not change the bundle identifier, signing settings, entitlements, workflow permissions, or required check names unless the issue is about exactly that.
- Never commit the generated `.xcodeproj`, secrets, API keys, or model files.

## Reporting bugs and security issues

**Bugs.** Open an issue with the [bug template](https://github.com/ryan-stoffel/hush/issues/new/choose). Include the Hush version, the macOS version, whether the Mac is Apple silicon or Intel, the app you were dictating into, the steps, and what you expected. For insertion bugs the target app and its version matter most. Do not attach recordings of your voice or paste history entries that contain anything private.

**Feature requests.** Use the feature template, or start in [Discussions](https://github.com/ryan-stoffel/hush/discussions) if the idea is still rough.

**Security issues.** Do not open a public issue. Use GitHub private vulnerability reporting: on the repository's Security tab choose "Report a vulnerability", or go to https://github.com/ryan-stoffel/hush/security/advisories/new. Anything that could leak audio, transcripts, history, or API keys, or that sends data off the machine without a cloud backend being selected, counts as a security issue here. The maintainer replies in the private advisory thread.

By contributing you agree that your contribution is licensed under the [MIT License](LICENSE).
