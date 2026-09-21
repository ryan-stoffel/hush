# Releasing Hush

This document is for maintainers. It describes how a release is cut, what `.github/workflows/release.yml` does, how code signing and notarization are set up, and how to recover from a bad release.

## Status

As of 2026-09-20 no signing secrets are configured and no signed release has been produced. Dev builds from `develop` are published without them. The signing path of the workflow (certificate import, `scripts/sign-and-notarize.sh`, notarization, stapling) is untested. The Sparkle appcast step is also untested, and Sparkle itself is not yet a dependency (it lands in the v1.0 milestone). Only the project skeleton exists today: the menu bar agent app shell, demo mode argument parsing, the UI test harness, and CI. Expect to fix things the first time each path runs for real, and update this document when you do.

## Overview of the release flow

Hush has two release channels, both produced by `release.yml` without anyone running commands by hand:

- **dev**: every push to `develop` (that is, every squash-merged pull request) builds the app and publishes a GitHub pre-release tagged `v<MARKETING_VERSION>-dev.<run number>`, for example `v0.2.0-dev.140`. `MARKETING_VERSION` comes from `project.yml`; the run number makes each build newer than the last.
- **final**: a maintainer merges `develop` into `main` and pushes a tag `vX.Y.Z` on the merge commit. That tag push runs the same workflow on the final channel.

Both channels update the Homebrew cask `hush` in `ryan-stoffel/homebrew-taps` when the `TAP_DEPLOY_KEY` (or `TAP_TOKEN`) secret is configured, so `brew upgrade hush` moves an installed copy to the newest build of either channel. See [Dev channel and Homebrew](#dev-channel-and-homebrew).

The workflow triggers on `push` to `develop`, `push` of tags matching `v*`, and `workflow_dispatch`. The single job, `release`, runs on a `macos-26` runner with a 90 minute timeout and these token permissions: `contents: write`, `pull-requests: write`, `issues: write`. Runs for the same ref queue behind each other instead of cancelling.

The job does the following, in order:

1. Checks out the repository with full history.
2. Works out the version. On a tag, `v0.1.0` gives `VERSION=0.1.0` and `CHANNEL=final`. On `develop`, it reads `MARKETING_VERSION` from `project.yml` and produces `VERSION=<that>-dev.<run number>`, `TAG=v<VERSION>`, `CHANNEL=dev`. A version containing a hyphen sets `PRERELEASE=true`.
3. Detects optional secrets. `HAS_SIGNING` is true when `SIGNING_CERT_P12_BASE64` is non-empty. `HAS_NOTARY` is true when both that and `NOTARY_PASSWORD` are non-empty. `HAS_SPARKLE_KEY` follows `SPARKLE_ED_PRIVATE_KEY`; `HAS_TAP_ACCESS` is true when `TAP_DEPLOY_KEY` or `TAP_TOKEN` exists.
4. Installs XcodeGen if it is missing, runs `xcodegen generate`, and archives a universal Release build (`ARCHS="arm64 x86_64"`, `ONLY_ACTIVE_ARCH=NO`) with ad-hoc signing (`CODE_SIGN_IDENTITY=-`). The app is copied from the archive to `build/export/Hush.app` and `lipo -archs` prints the slices to the log.
5. If `HAS_SIGNING` is true: imports the certificate into a temporary keychain and runs `scripts/sign.sh build/export/Hush.app App/Hush.entitlements`, which re-signs nested code and then the app with `SIGNING_IDENTITY`. Any identity works here; see [Which certificate to use](#which-certificate-to-use).
6. If `HAS_NOTARY` is true: runs `scripts/notarize.sh build/export/Hush.app`, which submits to `notarytool`, staples the ticket, and runs a Gatekeeper assessment. This only succeeds with a Developer ID identity.
7. Otherwise: see [What the workflow does when secrets are missing](#what-the-workflow-does-when-secrets-are-missing).
8. Zips the app with `ditto -c -k --sequesterRsrc --keepParent` to `build/Hush-<version>.zip` and records its SHA-256.
9. On the dev channel: creates the tag `v<version>` on the pushed commit and pushes it. Tags pushed with `GITHUB_TOKEN` do not start workflows, so this does not trigger a second run.
10. Builds the release notes. Dev builds list the commits since the previous dev tag; final releases use the CHANGELOG section or GitHub generated notes (see [CHANGELOG handling](#changelog-handling)).
11. Creates the GitHub release with `gh release create`, titled `Hush <version>`, with the zip attached, `--prerelease` for any version with a hyphen.
12. If `HAS_TAP_ACCESS` is true: writes `Casks/hush.rb` in `ryan-stoffel/homebrew-taps` with the new version, SHA-256, and download URL (`scripts/update_cask.py`) and pushes it. Otherwise a notice says the cask was not updated.
13. On the final channel with `HAS_SPARKLE_KEY`: updates `appcast.xml` on the `gh-pages` branch (see [Sparkle](#sparkle)).
14. On the final channel for non-pre-release versions: opens the CHANGELOG issue and pull request against `develop`.

The workflow does not check that a final tag points at a commit on `main`. That is the maintainer's responsibility. Tag only the merge commit of the `develop` to `main` pull request.

## Dev channel and Homebrew

Users install once and then upgrade:

```sh
brew tap ryan-stoffel/taps
brew trust ryan-stoffel/taps   # Homebrew 7 and later
brew install --cask ryan-stoffel/taps/hush
xattr -dr com.apple.quarantine /Applications/Hush.app
brew upgrade --cask hush
```

The cask token `hush` also exists in the main Homebrew cask tap for an unrelated Safari extension, so the first install must use the fully qualified name. After that `brew upgrade hush` refers to the installed cask.

Until builds are notarized, Gatekeeper blocks the downloaded app. Homebrew 7 removed the `--no-quarantine` option, so users either run `xattr -dr com.apple.quarantine /Applications/Hush.app` after each install or upgrade, or allow the app once in System Settings, Privacy and Security. The cask's caveats say the same.

The cask is generated by `scripts/update_cask.py` from a template: `app "Hush.app"`, `uninstall quit:` on the bundle id, `zap trash:` for the Application Support folder and the preferences file, `depends_on macos: ">= :sonoma"`, and caveats that differ for notarized and unnotarized builds.

`brew upgrade` installs whatever version the cask currently names, so a final release after a run of dev builds is picked up like any other update, and the next dev build after it too. Users who want only final releases can pin with `brew pin hush` between releases.

### Access to the tap

`GITHUB_TOKEN` cannot write to another repository, so the cask update needs its own credential. The preferred one is a deploy key, which belongs to the tap repository rather than to a person and needs no browser step:

```sh
ssh-keygen -t ed25519 -N "" -C "hush release workflow" -f tap_deploy_key
gh repo deploy-key add tap_deploy_key.pub --repo ryan-stoffel/homebrew-taps --title "hush release workflow" --allow-write
gh secret set TAP_DEPLOY_KEY --repo ryan-stoffel/hush < tap_deploy_key
rm tap_deploy_key tap_deploy_key.pub
```

The alternative is a fine-grained personal access token, stored as `TAP_TOKEN`. Create it at <https://github.com/settings/personal-access-tokens/new> with:

- Repository access: only `ryan-stoffel/homebrew-taps`.
- Repository permissions: Contents, read and write. Nothing else.
- An expiry you will remember to renew; the workflow logs a clear error when the push is refused.

Store it as an Actions secret on this repository:

```sh
gh secret set TAP_DEPLOY_KEY --repo ryan-stoffel/hush < tap_deploy_key
```

The workflow uses `TAP_DEPLOY_KEY` when it exists and falls back to `TAP_TOKEN`. Without either, every other step still runs and the release is still published; only the cask stays at its previous version.

### Which certificate to use

macOS ties Microphone, Accessibility, and Input Monitoring grants to the app's code signature. An ad-hoc signature changes with every build, so every upgrade of an ad-hoc build asks for all three permissions again. Any persistent certificate fixes that, because the grant is then bound to the certificate rather than to the build:

- A **Developer ID Application** certificate (Apple Developer Program, paid) is the only kind Gatekeeper accepts, and the only kind that can be notarized. Use it for public releases.
- An **Apple Development** certificate (free Apple Developer account, created by Xcode) or a **self-signed code signing certificate** (Keychain Access, Certificate Assistant, Create a Certificate, type Code Signing) signs the app just as well for permission stability. Gatekeeper still blocks the download, so users still need the `xattr` step or Open Anyway. Notarization is not possible; leave the `NOTARY_*` secrets unset.

Either way, export the certificate with its private key as a `.p12` from Keychain Access and store it as `SIGNING_CERT_P12_BASE64`, its password as `SIGNING_CERT_PASSWORD`, and the identity string from `security find-identity -v -p codesigning` as `SIGNING_IDENTITY`.

## Versioning

Hush follows [Semantic Versioning](https://semver.org). Tags are `vMAJOR.MINOR.PATCH`, with an optional pre-release suffix after a hyphen (`v0.1.0-beta.1`, `v1.0.0-rc.2`).

| Build setting | Info.plist key | Source in the release workflow |
| --- | --- | --- |
| `MARKETING_VERSION` | `CFBundleShortVersionString` | The tag with the leading `v` and any pre-release suffix removed (`${VERSION%%-*}`). `v0.1.0-beta.1` builds as `0.1.0`. |
| `CURRENT_PROJECT_VERSION` | `CFBundleVersion` | `GITHUB_RUN_NUMBER`, the run number of the `release` workflow. |

`project.yml` carries defaults (`MARKETING_VERSION: 0.1.0`, `CURRENT_PROJECT_VERSION: 1`) for local builds. The workflow overrides both on the `xcodebuild` command line, so nobody edits version numbers by hand for a release. The zip file name and the release title use the full version string, including any pre-release suffix.

Sparkle decides whether an update is newer by comparing `CFBundleVersion` (`sparkle:version` in the appcast), not the marketing version. It must increase with every published build or installed copies will not see the update. The workflow run number satisfies that: it goes up by one for every run of `release.yml` and never resets. It also distinguishes two builds that share a marketing version, for example `v0.1.0-beta.1` and `v0.1.0`, which both build as `0.1.0`. Re-running a failed run keeps the same run number, which is what you want: the same tag produces the same build number.

Consequence: do not rename `release.yml` or delete and recreate the workflow after Sparkle ships. A workflow with a new identity restarts its run numbers at 1.

## One-time code signing setup

You need an Apple Developer Program membership (paid). A free Apple ID cannot create Developer ID certificates or notarize.

1. Create the certificate. In Xcode: Settings, Accounts, select the team, Manage Certificates, add a "Developer ID Application" certificate. Alternatively create a certificate signing request in Keychain Access and upload it at <https://developer.apple.com/account/resources/certificates>. Only the Account Holder role can create Developer ID certificates.
2. Export it as a `.p12`. In Keychain Access, open the login keychain, My Certificates, expand "Developer ID Application: Your Name (TEAMID)" and confirm the private key is nested under it. Select the certificate, File, Export Items, format Personal Information Exchange (.p12). Set a strong export password. That password becomes `SIGNING_CERT_PASSWORD`.
3. Base64 encode it to the clipboard:

   ```sh
   base64 -i cert.p12 | pbcopy
   ```

4. Find the identity string:

   ```sh
   security find-identity -v -p codesigning
   ```

   The output has a line like `1) 0123456789ABCDEF0123456789ABCDEF01234567 "Developer ID Application: Your Name (ABCDE12345)"`. The quoted string is `SIGNING_IDENTITY`. The ten character code in parentheses is the team id. The team id is also shown at <https://developer.apple.com/account> under Membership details.
5. Create an app-specific password for `notarytool`. Sign in at <https://appleid.apple.com>, open Sign-In and Security, App-Specific Passwords, and generate one named something like `hush-notarytool`. It has the form `abcd-efgh-ijkl-mnop`. This is `NOTARY_PASSWORD`. It is not your Apple ID password.
6. Store the six signing secrets as described in the next section, then delete `cert.p12` from disk and clear the clipboard.

Developer ID Application certificates are valid for five years. When the certificate is renewed, export the new one and replace `SIGNING_CERT_P12_BASE64`, `SIGNING_CERT_PASSWORD`, and, if the name changed, `SIGNING_IDENTITY`.

## GitHub secrets

All secrets are repository Actions secrets on `ryan-stoffel/hush`. All are optional: the workflow publishes an ad-hoc signed build without them.

| Secret | What it is | How to produce it |
| --- | --- | --- |
| `SIGNING_CERT_P12_BASE64` | A code signing certificate and its private key, as a base64 encoded `.p12`. Developer ID for notarized releases; Apple Development or self-signed for permission-stable unnotarized builds. | `base64 -i cert.p12` |
| `SIGNING_CERT_PASSWORD` | The export password of that `.p12`. | Chosen during the Keychain Access export. |
| `SIGNING_IDENTITY` | The signing identity passed to `codesign --sign`, for example `Developer ID Application: Your Name (ABCDE12345)` or `Apple Development: Your Name (ABCDE12345)`. | `security find-identity -v -p codesigning` |
| `TAP_DEPLOY_KEY` | Private half of a deploy key with write access on `ryan-stoffel/homebrew-taps`. Preferred. | See [Access to the tap](#access-to-the-tap). |
| `TAP_TOKEN` | Fine-grained personal access token with Contents read and write on `ryan-stoffel/homebrew-taps`. Alternative to the deploy key. | See [Access to the tap](#access-to-the-tap). |
| `NOTARY_APPLE_ID` | The Apple ID email address used for notarization. | The Apple ID that belongs to the developer team. |
| `NOTARY_TEAM_ID` | The ten character Apple Developer team id. | The code in parentheses in the identity string, or Membership details in the developer account. |
| `NOTARY_PASSWORD` | An app-specific password for `notarytool`. | <https://appleid.apple.com>, App-Specific Passwords. |
| `SPARKLE_ED_PRIVATE_KEY` | The Sparkle EdDSA (ed25519) private key used to sign update archives. Needed from v1.0. | `generate_keys -x sparkle_private_key.txt`, see [Sparkle](#sparkle). |

Set them with the GitHub CLI. Commands that read from a pipe or a file keep the value out of shell history. Commands without input prompt for the value.

```sh
base64 -i cert.p12 | gh secret set SIGNING_CERT_P12_BASE64 --repo ryan-stoffel/hush
gh secret set SIGNING_CERT_PASSWORD --repo ryan-stoffel/hush
gh secret set SIGNING_IDENTITY --repo ryan-stoffel/hush --body "Developer ID Application: Your Name (ABCDE12345)"
gh secret set NOTARY_APPLE_ID --repo ryan-stoffel/hush
gh secret set NOTARY_TEAM_ID --repo ryan-stoffel/hush --body "ABCDE12345"
gh secret set NOTARY_PASSWORD --repo ryan-stoffel/hush
gh secret set SPARKLE_ED_PRIVATE_KEY --repo ryan-stoffel/hush < sparkle_private_key.txt
gh secret set TAP_DEPLOY_KEY --repo ryan-stoffel/hush < tap_deploy_key
```

Check the result with `gh secret list --repo ryan-stoffel/hush`.

Set the three `SIGNING_*` secrets together, and the three `NOTARY_*` secrets together. The workflow signs when `SIGNING_CERT_P12_BASE64` exists and notarizes when `NOTARY_PASSWORD` exists as well. If a group is incomplete, the certificate import, `scripts/sign.sh`, or `scripts/notarize.sh` fails and the job stops before a release is created.

How the workflow uses the certificate: it decodes the `.p12` into `$RUNNER_TEMP`, creates a temporary keychain with a random password, imports the certificate, runs `security set-key-partition-list` so `codesign` can use the key without a prompt, puts the keychain on the user search list, and deletes the decoded `.p12`. The keychain lives on the ephemeral runner and is discarded with it.

## Hardened runtime and entitlements

The app target enables the hardened runtime (`ENABLE_HARDENED_RUNTIME: YES` in `project.yml`), and `scripts/sign-and-notarize.sh` signs everything with `--options runtime` and a secure timestamp (`--timestamp`). Notarization requires both.

`App/Hush.entitlements` contains exactly one entitlement:

| Entitlement | Why |
| --- | --- |
| `com.apple.security.device.audio-input` | Under the hardened runtime, microphone access is denied without it, even after the user grants the microphone permission. |

The entitlements file is applied to the main app bundle only. Nested frameworks and helpers are signed without entitlements.

Hush is not sandboxed, and `com.apple.security.app-sandbox` must not be added. The planned dictation pipeline controls other apps through the Accessibility API (`AXUIElement`) and posts a synthetic Cmd+V to the frontmost app, and sandboxed apps cannot be granted Accessibility access to do this. The global hotkey also relies on a `CGEventTap`. For that reason Hush is not sandboxed and ships with Developer ID outside the Mac App Store, which requires the sandbox.

No hardened runtime exceptions (`allow-jit`, `disable-library-validation`, and so on) are present, and none should be added without an issue that explains the need. Entitlements and signing settings are on the list of things contributors and agents must not change.

## What the workflow does when secrets are missing

When `SIGNING_CERT_P12_BASE64` is empty:

- The certificate import, "Sign", and "Notarize" steps are skipped. The app keeps the ad-hoc signature from the archive step.
- A notice annotation says `Signing secrets are not configured. The build is ad-hoc signed and not notarized.`
- This note is appended to the release notes: "This build is ad-hoc signed and not notarized. macOS Gatekeeper blocks it until you allow it in System Settings, Privacy and Security, or run xattr -dr com.apple.quarantine /Applications/Hush.app. Permission grants do not survive upgrades of ad-hoc builds."

When the certificate exists but `NOTARY_PASSWORD` is empty: the app is signed with the certificate, "Notarize" is skipped, and the notes say the build is signed but not notarized.

When neither `TAP_DEPLOY_KEY` nor `TAP_TOKEN` exists: the cask step is skipped with the notice `Neither TAP_DEPLOY_KEY nor TAP_TOKEN is configured. The Homebrew cask in ryan-stoffel/homebrew-taps was not updated.`

When `SPARKLE_ED_PRIVATE_KEY` is empty: the appcast step is skipped with the notice `SPARKLE_ED_PRIVATE_KEY is not configured. The appcast was not updated.` Nothing is written to `gh-pages`.

The checks are independent. Do not configure the Sparkle key before a Developer ID certificate: that would advertise an unnotarized build to installed copies through the appcast.

Forks inherit none of the secrets, so a push in a fork produces an ad-hoc signed pre-release in that fork and nothing else.

## Signing and notarizing by hand on a Mac

Use this to test the signing setup before trusting CI, or to produce a release when Actions is unavailable. The commands mirror the workflow and `scripts/sign-and-notarize.sh`. The Developer ID certificate must be in your login keychain.

Build the universal archive. For a build that will be published, set `BUILD_NUMBER` to exactly one more than the `CFBundleVersion` of the last published release, not an arbitrary higher number. CI takes its build number from the run number of `release.yml`, so the next CI release must have a run number above the hand-built number, or Sparkle will not offer it to users on the hand-built copy. Check the latest run number first:

```sh
gh run list --repo ryan-stoffel/hush --workflow release.yml --limit 1 --json number
```

The next CI run gets that number plus one. If that would not be higher than your hand-built number, push throwaway pre-release tags until the run counter has passed it (before v1.0 only, because after v1.0 a pre-release tag reaches the appcast). Once Sparkle ships, prefer fixing CI over publishing by hand. For a local signing test that is never published, any number works.

```sh
VERSION=0.1.0
BUILD_NUMBER=8   # placeholder: last published CFBundleVersion (7 in this example) plus one

scripts/bootstrap.sh
xcodebuild archive \
  -project Hush.xcodeproj \
  -scheme Hush \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath build/Hush.xcarchive \
  -derivedDataPath DerivedData \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY=-
mkdir -p build/export
cp -R build/Hush.xcarchive/Products/Applications/Hush.app build/export/
lipo -archs build/export/Hush.app/Contents/MacOS/Hush
```

`lipo` must print `x86_64 arm64`.

The short way is to run the same script CI runs:

```sh
export SIGNING_IDENTITY="Developer ID Application: Your Name (ABCDE12345)"
export NOTARY_APPLE_ID="you@example.com"
export NOTARY_TEAM_ID="ABCDE12345"
read -rs NOTARY_PASSWORD && export NOTARY_PASSWORD
scripts/sign.sh build/export/Hush.app App/Hush.entitlements
scripts/notarize.sh build/export/Hush.app
```

The same steps, one command at a time, with the four variables above still exported:

```sh
APP=build/export/Hush.app

# 1. Nested code, inside out. Skip this block while the app has no Contents/Frameworks directory.
find "$APP/Contents/Frameworks" -type d \( -name "*.xpc" -o -name "*.app" \) -print0 |
  xargs -0 -n 1 codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY"
find "$APP/Contents/Frameworks" -type f -perm +111 -name "Autoupdate" -print0 |
  xargs -0 -n 1 codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY"
find "$APP/Contents/Frameworks" -maxdepth 1 \( -name "*.framework" -o -name "*.dylib" \) -print0 |
  xargs -0 -n 1 codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY"

# 2. The app itself, with entitlements.
codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" \
  --entitlements App/Hush.entitlements "$APP"

# 3. Verify the signature.
codesign --verify --deep --strict --verbose=2 "$APP"

# 4. Zip for submission and notarize. --wait blocks until Apple returns a verdict.
ditto -c -k --keepParent "$APP" build/submission.zip
xcrun notarytool submit build/submission.zip \
  --apple-id "$NOTARY_APPLE_ID" \
  --team-id "$NOTARY_TEAM_ID" \
  --password "$NOTARY_PASSWORD" \
  --wait

# 5. Staple the ticket to the app and check it.
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# 6. Ask Gatekeeper.
spctl --assess --type execute --verbose=2 "$APP"

# 7. Zip the stapled app for distribution. This is the file that gets uploaded.
ditto -c -k --sequesterRsrc --keepParent "$APP" "build/Hush-$VERSION.zip"
shasum -a 256 "build/Hush-$VERSION.zip"
```

Notes:

- Signing is done inside out, one bundle at a time, and never with `codesign --deep`. `--deep` applies the same options and entitlements to every nested bundle and is not reliable for signing. It is used only with `--verify`, where it is fine. Today the app has no `Contents/Frameworks` directory. The nested pass exists for Sparkle (v1.0), which ships XPC services, `Updater.app`, and the `Autoupdate` helper that each need their own signature before the framework and the app are sealed.
- The submission zip and the distribution zip are different files. The ticket is stapled to the `.app` after notarization, so the zip that users download must be created after `stapler staple`.
- `spctl` must print `accepted` and `source=Notarized Developer ID`.
- If notarization returns `Invalid`, read the log: `xcrun notarytool log <submission-id> --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD"`. The usual causes are an unsigned nested binary, a missing secure timestamp, or the hardened runtime not being enabled on a binary.

To publish a hand-built release, push the tag only if you want CI to run as well. Otherwise create the release from the existing tag with `gh release create vX.Y.Z build/Hush-X.Y.Z.zip --title "Hush X.Y.Z" --notes-file notes.md --verify-tag`.

## Sparkle

Sparkle is planned for the v1.0 milestone and is not a dependency yet (Sparkle 2, from 2.10.0, added by the v1.0 updater issue and not before). The appcast step already exists in `release.yml` and stays dormant until `SPARKLE_ED_PRIVATE_KEY` is set. The setup below is what v1.0 requires.

### Keys, once

1. Download the Sparkle release archive that matches the pinned version (the workflow uses 2.10.0) from <https://github.com/sparkle-project/Sparkle/releases> and unpack it. The tools are in `bin/`.
2. Run `./bin/generate_keys`. It creates an ed25519 key pair, stores the private key in your login keychain, and prints the public key. `./bin/generate_keys -p` prints the public key again later.
3. Put the public key in `App/Info.plist` as `SUPublicEDKey`, and set the feed URL:

   ```xml
   <key>SUFeedURL</key>
   <string>https://ryan-stoffel.github.io/hush/appcast.xml</string>
   <key>SUPublicEDKey</key>
   <string>BASE64_PUBLIC_KEY_FROM_GENERATE_KEYS</string>
   ```

4. Export the private key and store it as a secret:

   ```sh
   ./bin/generate_keys -x sparkle_private_key.txt
   gh secret set SPARKLE_ED_PRIVATE_KEY --repo ryan-stoffel/hush < sparkle_private_key.txt
   rm sparkle_private_key.txt
   ```

Keep a backup of the private key in a password manager. If it is lost, installed copies cannot verify any future update, and every user has to reinstall by hand. The public key is safe to commit. The private key must never be committed.

### What the workflow does

When `SPARKLE_ED_PRIVATE_KEY` is set, the "Update Sparkle appcast on gh-pages" step:

1. Downloads `Sparkle-2.10.0.tar.xz` from the Sparkle GitHub releases (version pinned by `SPARKLE_VERSION` in the step) and unpacks it to `$RUNNER_TEMP/sparkle`.
2. Fetches the `gh-pages` branch into `pages/`, or initializes a new orphan `gh-pages` branch if the remote does not have one.
3. Copies the release zip and the existing `appcast.xml` (if any) into `updates/`.
4. Runs `generate_appcast` with the private key on standard input, so the key never touches the runner's disk:

   ```sh
   echo "$SPARKLE_ED_PRIVATE_KEY" | generate_appcast --ed-key-file - \
     --download-url-prefix "https://github.com/ryan-stoffel/hush/releases/download/vX.Y.Z/" \
     --link "https://github.com/ryan-stoffel/hush" \
     updates
   ```

   `--download-url-prefix` points the new item's enclosure at the GitHub release asset, so the zip itself is never stored on `gh-pages`. Items already in `appcast.xml` keep their existing URLs.
5. Copies `updates/appcast.xml` to `pages/appcast.xml`, commits it as `github-actions[bot]` with the message `chore(release): appcast for vX.Y.Z`, and pushes to `gh-pages`.

The `gh-pages` branch hosts the Sparkle appcast and is written only by the release workflow. Never commit to it by hand, with the single exception described under [Rollback](#rollback).

The step runs for pre-release tags too. There is no beta channel configured, so once the key is set a tag such as `v1.1.0-beta.1` is offered to every installed copy. Until channels are added to the workflow, do not push pre-release tags after v1.0 unless that is the intent.

### GitHub Pages

After the first run creates the branch, enable Pages: repository Settings, Pages, Source "Deploy from a branch", branch `gh-pages`, folder `/ (root)`. Then check that <https://ryan-stoffel.github.io/hush/appcast.xml> returns the feed. Pages can take a minute to publish after each push.

### Gentle reminders for a Dock-less app

Hush is an agent app (`LSUIElement` is true): no Dock icon and usually no open window. Sparkle's standard scheduled update alert can open behind other apps, or take focus while the user is typing, and the user has no Dock icon to find it again. Sparkle 2 has an API for this case, called gentle scheduled update reminders. The v1.0 updater work must:

- Create the `SPUStandardUpdaterController` with a user driver delegate (`SPUStandardUserDriverDelegate`).
- Return `true` from `supportsGentleScheduledUpdateReminders`.
- Implement `standardUserDriverShouldHandleShowingScheduledUpdate(_:andInImmediateFocus:)` so that scheduled updates found in the background are not shown as a focus-taking alert, and implement `standardUserDriverWillHandleShowingUpdate(_:forUpdate:state:)` to show a quiet indicator instead: a badge on the status item and an "Update available" row in the popover.
- Clear the indicator in `standardUserDriverDidReceiveUserAttention(forUpdate:)` and `standardUserDriverWillFinishUpdateSession()`.
- Keep a user-initiated "Check for Updates" item in the popover. User-initiated checks may show the standard window immediately.

Per the privacy rule, the update check is the only network request the app makes with local backends selected, apart from the one-time model download, and the user must be able to disable it in Settings.

## CHANGELOG handling

`CHANGELOG.md` uses the Keep a Changelog format with a `## [Unreleased]` section at the top and compare links at the bottom. Pull request rule 6 applies to every change: "One issue per PR. Keep PRs small. Update CHANGELOG.md under Unreleased for anything user visible."

### Release notes

The "Release notes" step runs `python3 scripts/changelog_release.py notes --version <version>`, which prints the body of the `## [<version>]` section. If that section does not exist, or the output is empty, the workflow falls back to GitHub generated notes (`POST /repos/{owner}/{repo}/releases/generate-notes` for the tag). If the build is unsigned, the Gatekeeper note is appended.

So there are two ways to work:

- Cut the section before tagging. Rename the Unreleased entries into a `## [X.Y.Z] - YYYY-MM-DD` section on `develop` (through a normal issue and pull request) before opening the `develop` to `main` pull request. The release notes are then your curated text, and the workflow's CHANGELOG step finds nothing to do.
- Let the workflow cut it. Tag without a version section. The release notes are GitHub generated, and the workflow opens a pull request that records the version afterwards.

### The automatic pull request

For final releases only (`PRERELEASE=false`), the last step:

1. Checks out `origin/develop`.
2. Runs `scripts/changelog_release.py cut --version <version> --date <UTC date> --repo ryan-stoffel/hush --fallback-notes <generated notes>`. The script moves everything under `## [Unreleased]` into a new `## [<version>] - <date>` section, leaves an empty Unreleased section, and rewrites the link references: `[Unreleased]` compares `v<version>...HEAD`, and `[<version>]` compares the previous version tag to the new one, or links to the release tag page when there is no previous version. If Unreleased is empty it uses the GitHub generated notes, and if those are empty too it writes "Maintenance release." If the file already has a section for the version, it changes nothing.
3. If `CHANGELOG.md` is unchanged, logs that and exits successfully.
4. Otherwise opens an issue titled `chore(release): record <version> in CHANGELOG` with the labels `chore` and `release`, creates the branch `chore/gh-issue-<n>-changelog-<version>` (dots in the version become hyphens, for example `chore/gh-issue-57-changelog-0-1-0`, so the name passes the branch name check), commits as `github-actions[bot]`, pushes, and opens a pull request into `develop` titled `chore(release): record <version> in changelog`. The body contains `Closes #<n>`, a `## Before and After` section that says `No UI change`, and the screenshot markers, so it satisfies the pull request rules.

Things a maintainer needs to know:

- Pull requests opened with `GITHUB_TOKEN` do not start workflows. The required checks never report on their own. Close and reopen the pull request to run CI, then review and squash merge it like any other pull request.
- The step requires the repository setting that allows GitHub Actions to create pull requests: Settings, Actions, General, Workflow permissions, "Allow GitHub Actions to create and approve pull requests". Without it `gh pr create` fails with a permissions error.
- The labels `chore` and `release` must exist, or `gh issue create` fails.
- `CHANGELOG.md` on `develop` must contain a `## [Unreleased]` heading, or the script exits with an error.
- This step runs after the GitHub release is published. If it fails, the job is marked failed but the release and the appcast are already out. Fix the cause and open the CHANGELOG pull request by hand. Do not re-run the whole job (see [Rollback](#rollback)).

## Release checklist

### Before tagging

- [ ] Every issue in the milestone is closed or moved. `develop` is green.
- [ ] Run `docs/MANUAL_TEST.md` from start to finish on a real Mac, using a build of `develop`. Real dictation (microphone, global hotkey, Accessibility insertion) cannot run on a CI runner, so this is the only coverage those paths get.
- [ ] `CHANGELOG.md` on `develop`: Unreleased lists every user-visible change. Optionally cut the `## [X.Y.Z]` section now so the release notes are curated.
- [ ] Create the release issue and open the pull request from `develop` into `main` as described in [The release pull request](#the-release-pull-request). Wait for the required checks (`lint`, `unit-tests`, `ui-tests`, `branch-name`, `linked-issue`, `pr-format`, `screenshots`) and get one approving review. Merge with a merge commit. Do not squash.

### The release pull request

Only the `branch-name` check has a special case for `develop` into `main` (it accepts `develop` as the head branch). `linked-issue` and `pr-format` run `scripts/check_pr.py` on the release pull request exactly as they do on any other, and `screenshots` runs too. To pass them:

- Create a release issue first, with the labels `chore` and `release` and the milestone, for example titled `chore(release): release X.Y.Z`.
- Title the pull request with Conventional Commits and an allowed scope, for example `chore(release): release X.Y.Z`. The summary must start with a lowercase letter and have no trailing period.
- Put `Closes #<n>` (or `Fixes #<n>`) in the body, pointing at the release issue. GitHub closes the issue when the pull request merges into `main`, the default branch.
- Keep the `## Before and After` section from `.github/PULL_REQUEST_TEMPLATE.md` with the `<!-- screenshots:start -->` and `<!-- screenshots:end -->` markers. The `screenshots` job compares `main` with `develop` and fills in the table, which doubles as a visual summary of the release. Write `No UI change` only if that is true.

```sh
gh issue create --repo ryan-stoffel/hush --title "chore(release): release X.Y.Z" --label chore --label release --milestone "vX.Y"
gh pr create --repo ryan-stoffel/hush --base main --head develop --title "chore(release): release X.Y.Z"
```

`gh pr create` without `--body` opens an editor with the template. Fill in `Closes #<n>` and leave the markers alone.

### Tag

```sh
git checkout main
git pull --ff-only origin main
git tag -a vX.Y.Z -m "Hush X.Y.Z"
git push origin vX.Y.Z
```

### After tagging

- [ ] Watch the run: `gh run watch --repo ryan-stoffel/hush` or the Actions tab. Check the annotations. A "Signing secrets are not configured" or "appcast was not updated" notice on a release that was meant to be signed means a secret is missing.
- [ ] In the log of the archive step, confirm `lipo` printed both `x86_64` and `arm64`.
- [ ] Download the zip from the release page with a browser, so the file is quarantined the way a user's copy is. Unzip it and run:

  ```sh
  spctl --assess --type execute --verbose=2 Hush.app
  xcrun stapler validate Hush.app
  codesign --verify --deep --strict --verbose=2 Hush.app
  codesign -d --entitlements - Hush.app
  ```

  - Signed releases (signing secrets configured): expect `accepted` with `source=Notarized Developer ID`, a valid stapled ticket, and only the `audio-input` entitlement.
  - Ad-hoc releases (no signing secrets, which is every release until the secrets are set): expect `spctl` to print `rejected` and `stapler validate` to fail. That is by design, not a broken release. Confirm the release notes end with the Gatekeeper note, confirm `codesign -d --entitlements -` shows only `audio-input`, and confirm `codesign --verify` still passes.
- [ ] Launch the downloaded app on a clean macOS user account (no prior permissions, no prior settings). A signed release must open without a Gatekeeper warning beyond the standard "downloaded from the internet" prompt. An ad-hoc release is blocked on first launch: allow it in System Settings, Privacy and Security, then launch again. Check the version: `defaults read "$PWD/Hush.app/Contents/Info" CFBundleShortVersionString` and `CFBundleVersion`.
- [ ] Verify the appcast (v1.0 and later): `curl -fsSL https://ryan-stoffel.github.io/hush/appcast.xml`. The newest item must have the new `sparkle:version` (the run number), the right `sparkle:shortVersionString`, an `sparkle:edSignature`, and an enclosure URL under `https://github.com/ryan-stoffel/hush/releases/download/vX.Y.Z/` that downloads. Then run "Check for Updates" from an installed copy of the previous release.
- [ ] Final releases: close and reopen the CHANGELOG pull request so CI runs, review it, squash merge it.
- [ ] Close the milestone.

## Rollback

Prefer rolling forward. Sparkle never downgrades an installed copy, so users who already updated can only be fixed by a newer build. Revert or fix on `develop`, merge `develop` into `main`, and tag the next patch version. Its build number is higher automatically because the workflow run number only goes up.

Never move or reuse a published tag. Users, the appcast, and the CHANGELOG compare links all refer to it. A broken `vX.Y.Z` is followed by `vX.Y.(Z+1)`.

If a release must stop spreading before the fix is ready:

1. Demote it on GitHub so it is no longer "Latest": `gh release edit vX.Y.Z --prerelease --repo ryan-stoffel/hush`, and add a warning at the top of the notes. If the build is harmful, delete the release and keep the tag: `gh release delete vX.Y.Z --yes --repo ryan-stoffel/hush`.
2. If the appcast already lists the build (v1.0 and later), remove its `<item>` from `appcast.xml` on `gh-pages` and push. This is the one case where a maintainer edits `gh-pages` by hand. Do it before deleting the release asset, otherwise installed copies are offered an update whose download fails. Removing the item stops new offers. It does not affect copies that already updated.
3. Tag the fixed patch release as soon as it is ready.

If the workflow fails part way:

- Failure before "Create GitHub release" (build, signing, notarization): nothing was published. Fix the cause and use "Re-run failed jobs". The re-run keeps the same run number, so the build number is unchanged. If the fix needs a code change, the tag now points at the wrong commit: do not move it, delete nothing, and tag the next patch version from the fixed `main`.
- Failure after the release was created (appcast or CHANGELOG step): do not re-run the job as is. `gh release create` fails because the release exists. Either finish the remaining step by hand, or delete the release with `gh release delete vX.Y.Z --yes` (without `--cleanup-tag`, so the tag stays) and then re-run the job.
- A re-run after the appcast step already pushed fails at the commit in that step if `appcast.xml` did not change. In that case the appcast is already correct and only the CHANGELOG pull request remains, which you can open by hand with `scripts/changelog_release.py cut`.

If a secret leaks:

- Developer ID certificate or its password: revoke the certificate in the Apple developer account, create a new one, and replace the three `DEVELOPER_ID_*` secrets. Copies that are already installed keep running, but Gatekeeper blocks new installs of every build signed with the revoked certificate. After replacing the secrets, tag a new patch release so there is a downloadable build signed with the new certificate, and mark older releases accordingly (a warning at the top of their notes that the download no longer passes Gatekeeper).
- App-specific password: revoke it at <https://appleid.apple.com>, create a new one, replace `NOTARY_PASSWORD`.
- Sparkle private key: this is the serious one. Generate a new pair, ship a release signed with the old key whose `Info.plist` carries the new `SUPublicEDKey`, then switch the secret to the new key. Because updates are also verified against the Developer ID code signature, Sparkle supports rotating one of the two at a time, never both in the same release.
