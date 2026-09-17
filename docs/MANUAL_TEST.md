# Manual test checklist

This is the checklist for everything CI cannot cover. It is run by a person, on a real Mac, with a real microphone.

## Why this exists

CI runs on GitHub-hosted macOS runners. Those machines cannot exercise the core of Quoth:

- They have no microphone input, so `AudioCaptureService` has nothing to capture.
- The app under test has no Accessibility grant and no Input Monitoring grant, and there is no way to grant them on a hosted runner. The Fn key event tap and the synthetic Cmd+V cannot run.
- They have no Neural Engine, so on-device Whisper inference does not run the way it does on a user's Mac.
- The XCUITest suite launches the app with `-demoMode YES -demoScene <name>`. In demo mode the app never touches the microphone, event taps, Accessibility, the Keychain, or the network. The UI tests prove that windows render. They prove nothing about dictation.

What CI does cover: lint, unit tests for `QuothCore` and the headless parts of `QuothKit`, and the screenshot suite. Everything between "the user holds a key" and "text appears in another app" is verified here.

## Status of this document

As of 2026-09-17 only the project skeleton is merged: the menu bar agent app shell, demo mode argument parsing, the UI test harness, and CI. The v0.1 features (menu bar, hotkey, capture, local transcription, paste insertion) are in progress.

The sections below describe the expected behavior of the finished features. A section applies once the feature it tests is merged into `develop`. Until then, mark its items `n/a` when you record results. Each feature issue extends its section in the same PR that builds the feature: it adds checks for the behavior it introduces and corrects any expected result that the implementation changed.

| Section | Milestone | Applies today |
| --- | --- | --- |
| 1. Setup | skeleton | yes |
| 2. Launch and menu bar | v0.1 | partly (no Dock icon, not in Cmd+Tab, launch opens no window; quit with `pkill -x Quoth` until the popover exists) |
| 3. Permissions | v0.1 | no |
| 4. Hotkey | v0.1 | no |
| 5. Audio capture | v0.1 | no |
| 6. Overlay | v0.1 | no |
| 7. Transcription | v0.1 | no |
| 8. Insertion matrix | v0.1 | no |
| 9. Clipboard restore | v0.1 | no |
| 10. End to end | v0.1 | no |
| 11. Privacy checks | v0.1 | partly (UserDefaults and network checks work on the shell app) |
| 12. Idle resource use | v0.1 | partly (the skeleton check at the end of the section) |
| 13. Later milestones | v0.2, v0.3, v1.0 | no |

## When to run it

- Any PR that touches audio, hotkey, transcription, or insertion code runs the matching sections and says so in the PR. "Matching" means the section named after the area plus section 10 (End to end). Insertion changes also run section 9.
- The whole document is run before every release, on the `develop` commit that will be merged into `main` for the release. See docs/RELEASING.md.

If you cannot run a section (for example you have no external keyboard), say which items you skipped and why. A skipped item is fine. An unreported skipped item is not.

## How to record results

Copy the relevant sections into the PR description (for a PR) or into the release issue (for a release). The release issue is the one docs/RELEASING.md describes under "The release pull request": titled `chore(release): release X.Y.Z`, labels `chore` and `release`. Create it before the run if it does not exist yet. Tick the boxes that pass. For anything that fails, leave the box empty and write what happened under it. Put this header above the copied checklist:

```
Manual test run
Mac model:      (for example MacBook Pro 14-inch, M3 Pro, 2023)
macOS version:  (for example 15.6.1, from `sw_vers -productVersion`)
Commit SHA:     (from `git rev-parse HEAD`)
Input devices:  (for example built-in mic, AirPods Pro, Magic Keyboard)
Sections run:   (for example 1, 5, 10)
```

In a PR, put the header and the copied checklist in the `## Testing` section of the PR template and tick the docs/MANUAL_TEST.md box there. Demote the copied section headings to `###` so they stay inside Testing. Do not put anything between the `<!-- screenshots:start -->` and `<!-- screenshots:end -->` markers.

A failure found before a release blocks the release until it is fixed or the maintainer (@ryan-stoffel) accepts it in writing in the release issue.

## 1. Setup

Start from a clean build and clean permissions so that results are comparable between runs.

- [ ] Tools are installed: `scripts/bootstrap.sh` (or `brew install xcodegen swiftformat swiftlint`, then `xcodegen generate`).
- [ ] Quit any running copy of Quoth: `pkill -x Quoth` (no output and a non-zero exit code means none was running).
- [ ] Remove old build products: `rm -rf DerivedData build`.
- [ ] Build: `xcodebuild -project Quoth.xcodeproj -scheme Quoth -destination 'platform=macOS' -derivedDataPath DerivedData build`. Expected: `BUILD SUCCEEDED`.
- [ ] Reset every privacy grant for the app: `tccutil reset All io.github.ryan-stoffel.quoth`. Expected: `Successfully reset All approval status for io.github.ryan-stoffel.quoth`.
- [ ] Clear stored preferences if you want a true first run: `defaults delete io.github.ryan-stoffel.quoth` (an error saying the domain does not exist is fine).
- [ ] Launch the app normally, without demo mode arguments: `open DerivedData/Build/Products/Debug/Quoth.app`.
- [ ] Record the commit SHA, Mac model, and macOS version in the results header.

Notes on TCC and ad-hoc signing:

- Local builds are ad-hoc signed (`CODE_SIGN_IDENTITY: "-"` in project.yml). macOS ties Accessibility and Input Monitoring grants to the code signature. An ad-hoc signature changes with every rebuild, so a rebuild can silently invalidate a grant: System Settings still shows Quoth as enabled, but the event tap or the synthetic paste no longer works.
- If the hotkey or insertion stops working after a rebuild, do not file a bug yet. Run `tccutil reset All io.github.ryan-stoffel.quoth`, relaunch, grant again, and retest.
- Always test the app from the same path. A second copy of Quoth.app elsewhere on disk shares the bundle id and confuses the permission lists.
- Builds signed with a Developer ID keep their grants across updates. As of 2026-09-17 no signing secrets are configured, so `release.yml` produces ad-hoc signed builds and the signing path is untested. A signed build exists only after a tag is pushed. Once signing is set up, push a pre-release tag (for example `vX.Y.Z-rc.1`, see Versioning in docs/RELEASING.md) to get a signed build from `release.yml`, and run sections 3, 4, 8 and the Signed release checks against it before tagging the final version. Do this only while `SPARKLE_ED_PRIVATE_KEY` is not set: once it is, a pre-release tag also reaches the appcast.

## 2. Launch and menu bar

- [ ] No Dock icon appears at launch or at any later point (`LSUIElement` is set in App/Info.plist).
- [ ] Quoth does not appear in the Cmd+Tab switcher.
- [ ] Launching the app does not open any window when onboarding has already been completed.
- [ ] A status item is visible in the menu bar. It is legible in both light and dark menu bars and with "Reduce transparency" on.
- [ ] Clicking the status item opens the popover. Clicking outside closes it. Pressing Escape closes it.
- [ ] The status item icon reflects each `DictationState`: idle, listening (while the hotkey is held), transcribing (after release), and error. It returns to idle after each dictation.
- [ ] With many menu bar items or a notched display, the status item is still reachable. If macOS hides it behind the notch, note that in the results.
- [ ] Launching a second copy does not produce two status items.
- [ ] Quit from the popover or menu terminates the process: `pgrep -x Quoth` prints nothing.
- [ ] Closing every Quoth window does not quit the app (`applicationShouldTerminateAfterLastWindowClosed` returns false).

## 3. Permissions

Quoth needs three grants. Microphone: capture. Accessibility: post the synthetic Cmd+V and use the AX API. Input Monitoring: the listen-only CGEventTap that sees the Fn key.

Run each block from a reset state (`tccutil reset All io.github.ryan-stoffel.quoth`, then relaunch).

### Microphone

- [ ] The system microphone prompt appears the first time capture is requested, with a usage description that explains why Quoth needs the microphone (`NSMicrophoneUsageDescription` in App/Info.plist, added by the audio capture issue; without it macOS kills the app on first capture). It does not appear at launch before the user has done anything.
- [ ] Click "Don't Allow". Expected: no crash, no hang in the listening state. The app shows a clear error that names the microphone permission and says where to fix it (System Settings, Privacy and Security, Microphone).
- [ ] Holding the hotkey again while denied shows the same error. It does not show the system prompt again (macOS only prompts once) and it does not fail silently.
- [ ] Enable Quoth under System Settings, Privacy and Security, Microphone. Expected: the app detects the grant without a relaunch, or tells the user plainly that a relaunch is needed. Dictation then works.

### Accessibility

- [ ] When insertion is first needed, the app explains why it needs Accessibility and opens, or links to, System Settings, Privacy and Security, Accessibility.
- [ ] With Accessibility not granted, dictate a sentence. Expected: a clear error that names Accessibility. The transcript is not lost: it is left on the clipboard or shown so the user can copy it. Record which.
- [ ] Grant Accessibility while the app is running. Expected: the app detects the grant within a few seconds without a relaunch, and the next dictation inserts text.
- [ ] Revoke Accessibility while the app is running. Expected: the next dictation reports the missing permission. No crash.

### Input Monitoring

- [ ] With Input Monitoring not granted, holding Fn does nothing harmful. The app surfaces that the hotkey cannot work and names Input Monitoring.
- [ ] The app opens, or links to, System Settings, Privacy and Security, Input Monitoring.
- [ ] Grant Input Monitoring. Expected: the hotkey starts working. If macOS requires a relaunch for the event tap to be created, the app says so instead of appearing broken.
- [ ] Revoke Input Monitoring while the app is running. Expected: the app notices that the tap is disabled and reports it. It does not spin or leak CPU (check Activity Monitor).

### All three

- [ ] With all three granted, relaunch. Expected: no prompts, no permission errors, dictation works immediately.
- [ ] The popover or settings shows the current state of each permission, and the state matches System Settings.

## 4. Hotkey

Default hotkey: hold Fn (Globe) to talk, release to stop. Logic lives in `HotkeyStateMachine` (unit tested). The event tap in `FnKeyMonitor` / `EventTapHotkeyMonitor` is what needs a human.

- [ ] Hold Fn for two seconds. Expected: listening starts within a moment of key down and stops on key up.
- [ ] Quick tap of Fn (press and release as fast as you can). Expected: nothing is inserted, no error is shown, the overlay does not flash or flashes and dismisses cleanly. Record which.
- [ ] Fn+arrow keys (Home, End, Page Up, Page Down) do not start a dictation, and still scroll or move the caret as normal.
- [ ] Fn+F-keys (brightness, volume, or F1 to F12, depending on the keyboard setting) do not start a dictation and still work.
- [ ] Fn+Delete (forward delete) does not start a dictation and still deletes.
- [ ] Hold Fn, then press another key mid-dictation. Expected: the behavior is consistent (either the dictation is cancelled or it continues). Record which. No stuck listening state.
- [ ] The hotkey works while another app is frontmost (TextEdit, Safari). Quoth never becomes the frontmost app.
- [ ] The hotkey works while another app is in native full screen.
- [ ] The hotkey works on a second Space and on a second display.
- [ ] Hold Fn, switch apps with Cmd+Tab while still holding, release. Expected: no stuck state. Text goes to the app that is frontmost at release, or the dictation is cancelled. Record which.
- [ ] After sleep and wake, the hotkey still works without relaunching.
- [ ] After fast user switching away and back, the hotkey still works.
- [ ] Secure input: focus a password field in Safari or run `sudo -v` in Terminal with "Secure Keyboard Entry" on. macOS blocks event taps during secure input. Expected: the hotkey does nothing, the app does not get stuck, and it recovers when secure input ends.

External keyboards:

- [ ] Apple Magic Keyboard (has Fn/Globe): hold Fn works the same as the built-in keyboard.
- [ ] Third-party keyboard without an Fn key, or whose Fn key is handled in keyboard firmware and never reaches macOS: holding its Fn does nothing, which is expected. The app must offer a way to choose another hotkey (settings, v0.2). Until settings exist, record that Fn is not available on this keyboard.
- [ ] With a third-party keyboard attached, Fn on the built-in keyboard still works.

Globe key system setting (System Settings, Keyboard, "Press Globe key to"). Quoth uses a listen-only tap, so it cannot stop macOS from also acting on the key. Test each value and record what happens on hold and on quick tap:

- [ ] "Do Nothing": dictation works and macOS does nothing else. This is the recommended setting.
- [ ] "Change Input Source": record whether the input source changes after a hold.
- [ ] "Show Emoji & Symbols": record whether the picker opens after a hold, and whether it steals the inserted text.
- [ ] "Start Dictation" (press twice): record whether Apple dictation is triggered by normal Quoth use.
- [ ] If any value other than "Do Nothing" breaks dictation, the app must tell the user about the setting. Record whether it does.

Hands-free toggle mode, once merged:

- [ ] The toggle gesture starts listening without holding. The same gesture stops it. The overlay makes it obvious that capture is still running.

## 5. Audio capture

`AudioCaptureService` uses AVAudioEngine and converts to 16 kHz mono Float32 in memory.

- [ ] Built-in microphone as system default input: dictate a sentence. Expected: levels move in the overlay and the transcript is correct.
- [ ] AirPods (or another Bluetooth headset) as system default input. Expected: capture works. Note the delay before capture starts: Bluetooth switches to a low-quality call profile and the first word is often clipped. Record whether the first word is lost.
- [ ] USB microphone or audio interface as system default input, including one that runs at 48 kHz or 96 kHz and one with more than one channel if available. Expected: capture works, no pitch shift, no crash in format conversion.
- [ ] Change the system default input between two dictations (System Settings, Sound, Input). Expected: the next dictation uses the new device without a relaunch.
- [ ] Unplug or disconnect the active input device during capture. Expected: no crash and no hang. Either the dictation ends with a clear error or capture continues on the new default device. Record which. The state returns to idle.
- [ ] Put AirPods back in the case during capture. Same expectations as above.
- [ ] No input device at all (Mac mini or Mac Studio with nothing attached, if available). Expected: a clear error, no crash.
- [ ] Another app is using the microphone (a FaceTime or Zoom call). Expected: dictation still works and the call audio is not disturbed.
- [ ] The orange microphone indicator in the menu bar appears only while the hotkey is held and disappears within a few seconds of release. It is never lit while idle.
- [ ] 10 minute cap: start a dictation (hands-free mode, or hold the key) and let it run past 10 minutes. Expected: capture stops at the cap by itself, the user is told why, the audio captured so far is transcribed, and memory does not keep growing after the cap.
- [ ] Memory during a long capture stays bounded: about 38 MB per 10 minutes of 16 kHz mono Float32 (16000 samples x 4 bytes x 600 s), plus overhead. Watch Activity Monitor.

No audio on disk. Audio is never written to disk. Verify it, do not assume it:

- [ ] While capturing, list the files the process has open: `lsof -p "$(pgrep -x Quoth)" | grep -Ei '\.(wav|caf|aif|aiff|m4a|mp3|flac|pcm|raw)'`. Expected: no output.
- [ ] While capturing, look at every regular file open for writing: `lsof -p "$(pgrep -x Quoth)" | awk '$4 ~ /[0-9]+[wu]/ && $5 == "REG"'`. Expected: nothing that could hold audio. Log files and the JSON stores are fine. Anything that grows while you speak is a failure.
- [ ] After several dictations, search the places the app can write. The app is not sandboxed, so it has no `~/Library/Containers` entry. Check that too, so that a future sandboxing change does not go unnoticed:

  ```
  find ~/Library/Application\ Support/Quoth \
       ~/Library/Caches/io.github.ryan-stoffel.quoth \
       ~/Library/Containers/io.github.ryan-stoffel.quoth \
       "$TMPDIR" /private/tmp \
       -type f -mmin -30 \
       \( -iname '*.wav' -o -iname '*.caf' -o -iname '*.aif*' -o -iname '*.m4a' -o -iname '*.mp3' -o -iname '*.flac' -o -iname '*.pcm' -o -iname '*.raw' \) \
       2>/dev/null
  ```

  Expected: no output. Directories that do not exist are fine. `/private/tmp` is used because `/tmp` is a symlink on macOS and `find` does not follow it.
- [ ] List everything the app wrote in the last 30 minutes, whatever the extension: `find ~/Library/Application\ Support/Quoth ~/Library/Caches/io.github.ryan-stoffel.quoth -type f -mmin -30 -exec ls -la {} + 2>/dev/null`. Expected: only small, explainable files. Any file of several hundred kilobytes or more that appeared after a dictation needs an explanation. Model files are the exception.
- [ ] The temporary directories are shared with every other app, so list only large recent files there: `find "$TMPDIR" /private/tmp -type f -mmin -30 -size +200k -exec ls -la {} + 2>/dev/null`. Look only at files you can attribute to Quoth (by name, or because they appear in the `lsof` output above). Expected: none.
- [ ] Force quit during capture (`pkill -9 -x Quoth`), then repeat the three `find` commands. Expected: still no audio on disk.

## 6. Overlay

`OverlayPanelController` is a non-activating NSPanel. It must never take focus.

- [ ] The overlay appears at the bottom center of the screen that holds the focused window (or the main screen: record which), above the Dock, and does not overlap the Dock when the Dock is visible.
- [ ] With the Dock on the left or right, or hidden, the position is still sensible.
- [ ] The waveform reacts to voice: flat in silence, visibly moving when speaking, larger when louder. It does not freeze.
- [ ] Elapsed time counts up from 0:00 in whole seconds and matches a stopwatch over 30 seconds.
- [ ] The frontmost app keeps focus: its window title bar stays active and its menu bar stays in place.
- [ ] The caret in the frontmost app's text field keeps blinking while the overlay is visible. Type a letter with the other hand while holding Fn: it lands in the text field.
- [ ] Clicking on the overlay does not activate Quoth and does not take focus from the text field.
- [ ] The overlay is visible over an app in native full screen (Safari, Keynote in presentation mode if available).
- [ ] The overlay is visible on every Space. Hold the hotkey, switch Space with Ctrl+arrow: the overlay follows.
- [ ] With two displays, the overlay appears on one display only, and on the expected one.
- [ ] After release, the overlay switches to the transcribing state and stays until text is inserted, then dismisses.
- [ ] Error state: force an error (deny the microphone, or dictate with the model removed). Expected: the overlay shows a short readable message, then dismisses by itself after a few seconds or on the next hotkey press. It never stays on screen forever.
- [ ] The overlay does not appear in screenshots of other windows taken with Cmd+Shift+4 then Space (window capture). Full screen captures may include it. Record the behavior.
- [ ] Legible in light and dark appearance, with "Increase contrast" and with "Reduce motion" (the waveform may simplify but must still show level).
- [ ] VoiceOver on: starting and stopping a dictation does not move the VoiceOver cursor away from the text field.

## 7. Transcription

Default backend: `WhisperKitBackend`, on device. WhisperKit does not officially support Intel Macs. On an Intel Mac the local backend reports itself unavailable and a cloud backend (v0.3) is required, so on Intel run only the first item below.

- [ ] Intel Mac only: the app says clearly that on-device transcription is not available on this Mac. It does not crash and does not start a model download.

First run model download:

- [ ] Remove any previously downloaded model so that this is a true first run. The transcription issue records the model folder path here when it lands.
- [ ] The first dictation (or onboarding, v1.0) starts the model download. Progress is visible and moves. The user is told the approximate size.
- [ ] Dictating while the download is in progress gives a clear "model is still downloading" message. No crash and no silent drop.
- [ ] Turn Wi-Fi off mid-download. Expected: a clear error. Turn Wi-Fi on: the download resumes or restarts on retry. No corrupt half-model is used.
- [ ] Quit during the download and relaunch. Expected: the download resumes or restarts cleanly.
- [ ] After the download, the first transcription may be slow while Core ML compiles the model for this machine. Expected: the transcribing state stays visible for that time. Record the duration.

Offline after download:

- [ ] Turn Wi-Fi off and unplug Ethernet. Dictate a sentence. Expected: it transcribes and inserts exactly as it does online, with no error and no noticeable extra delay.
- [ ] Relaunch the app while offline and dictate again. Expected: same result. Turn the network back on afterwards.

Content:

- [ ] English sentence: "The quick brown fox jumps over the lazy dog, and then it went home." Expected: correct words, sensible capitalization and punctuation.
- [ ] Numbers and names: "Meet me at 4:30 on March 3rd at 221B Baker Street." Record the output.
- [ ] A non-English sentence with language auto-detect, for example Spanish: "Manana por la manana voy a comprar pan y leche." (speak it with the natural pronunciation). Expected: output in Spanish, not translated to English, with the correct accents and the letter n with tilde in the first word. Record the language used.
- [ ] Switch languages between two dictations (English, then the other language, then English). Expected: each is detected on its own.
- [ ] Silence: hold the hotkey for five seconds without speaking. Expected: nothing is inserted. In particular no hallucinated text such as "Thank you." or "Thanks for watching." and no bracketed tags such as "[BLANK_AUDIO]".
- [ ] Background noise only (fan, music without vocals): same expectation as silence.
- [ ] Very short utterance: "Yes." or "OK." with a hold of under one second. Expected: the word is inserted, or nothing is inserted. Never an error and never unrelated text.
- [ ] Long dictation over 30 seconds (Whisper works in 30 second windows): read a paragraph for 60 to 90 seconds. Expected: the whole text is present, in order, with no missing or repeated sentence at the 30 second boundaries.
- [ ] Very long dictation (5 minutes). Expected: it completes. Record the transcription time and the peak memory from Activity Monitor.
- [ ] Whispered speech and fast speech: record the quality. These are informational, not pass or fail.
- [ ] Two dictations back to back, the second started while the first is still transcribing. Expected: defined behavior (queued or refused with a message). No interleaved or lost text. Record which.

## 8. Insertion matrix

For each app: click into the text area, type "before " so there is existing text, put something recognizable on the clipboard (copy the word "CLIPBOARD" from elsewhere), dictate "this is a test", then press Cmd+V.

- Inserted correctly: the transcript appears once, at the caret, with existing text untouched, no missing first character, no doubled text.
- Clipboard restored: the Cmd+V after the dictation pastes "CLIPBOARD", not the transcript.
- Focus kept: the same window and the same field are focused after insertion, and the caret is at the end of the inserted text.

Fill in yes, no, or n/a, and the strategy used if the app exposes it (`accessibility` or `clipboardPaste`, chosen by `InsertionStrategySelector`). v0.1 ships paste insertion. Accessibility insertion is added later, and its issue adds a column here.

| App | Version tested | Inserted correctly | Clipboard restored | Focus kept | Notes |
| --- | --- | --- | --- | --- | --- |
| TextEdit (rich text) | | | | | |
| TextEdit (plain text) | | | | | |
| Notes | | | | | |
| Mail (compose body) | | | | | |
| Mail (subject field) | | | | | |
| Safari, `<textarea>` | | | | | |
| Safari, address bar | | | | | |
| Chrome, `<textarea>` | | | | | |
| Google Docs (in Chrome) | | | | | |
| Slack (message field) | | | | | |
| VS Code (editor) | | | | | |
| Xcode (source editor) | | | | | |
| Terminal | | | | | |
| iTerm2 | | | | | |
| Spotlight search field | | | | | |
| Password field (Safari login form) | | see below | see below | see below | |

A plain `<textarea>` for the browser rows: open `data:text/html,<textarea rows=10 cols=60 autofocus></textarea>` in the address bar.

Per-app expectations:

- [ ] Google Docs and Slack are web or Electron editors with their own input handling. Expected: text appears once. Watch for doubled text and for a lost first character.
- [ ] VS Code and Xcode: no autocomplete popup swallows part of the text, and no auto-indent or bracket pairing mangles it.
- [ ] Terminal and iTerm2: the text appears at the prompt and is not executed. The transcript must not end with a newline. With "Secure Keyboard Entry" enabled in Terminal, the hotkey is blocked by macOS: that is expected, record it.
- [ ] iTerm2 may show a paste warning for multi-line text. Record whether a single sentence triggers it.
- [ ] Multi-line dictation (say "new line" once spoken punctuation lands in v0.2) in Slack and in a terminal: a newline does not send the message or run a command by accident. Record the behavior.

Password field. The field is a secure text field, and macOS enables secure input while it is focused, which blocks event taps. Expected safe behavior:

- [ ] Most likely the hotkey does nothing while the field is focused. That is a pass. The app must not get stuck in the listening state.
- [ ] If a dictation does start (for example it began before the field was focused), Quoth either refuses to insert and says why, or inserts the text. The insertion issue decides which and updates this item. In both cases the hard requirements are: Quoth never reads the contents of a secure field through the AX API, the transcript is not written to history (v0.2), and the clipboard is restored.
- [ ] After leaving the password field, dictation into a normal field works again without a relaunch.

Other insertion cases:

- [ ] No text field focused (Finder desktop is frontmost). Expected: no crash and no system beep storm. The transcript is not lost: it is left on the clipboard or shown to the user, with a message. Record which.
- [ ] Text selected before dictating: the transcript replaces the selection, as a normal paste would.
- [ ] Focus changes between release and insertion (click another app during transcription). Expected: text goes to the app that is frontmost at insertion time, or insertion is cancelled. Never into a field the user cannot see. Record which.
- [ ] Undo (Cmd+Z) in TextEdit and Notes after insertion removes the inserted text in one step.
- [ ] Emoji, accented characters, and CJK text in a transcript are inserted intact (use the non-English sentence from section 7).

## 9. Clipboard restore

`PasteInserter` saves the clipboard, writes the transcript, posts a synthetic Cmd+V, and restores the clipboard. Before each item, put the named content on the clipboard, dictate into TextEdit, then check the clipboard.

- [ ] Plain text: copy a word. After dictation, Cmd+V pastes that word.
- [ ] Image: copy an image from Preview (Cmd+A, Cmd+C) or take a screenshot to the clipboard (Cmd+Ctrl+Shift+4). After dictation, paste into a rich TextEdit document or use Preview, File, New from Clipboard. Expected: the same image.
- [ ] File: copy a file in Finder. After dictation, Cmd+V in another Finder folder pastes the file itself, not its name.
- [ ] Several files copied in Finder: all of them are restored.
- [ ] Rich text: copy bold, colored text with a link from Safari or Pages. After dictation, paste into a rich TextEdit document. Expected: formatting and link intact, not flattened to plain text.
- [ ] Every pasteboard type survives: run `osascript -e 'clipboard info'` before and after a dictation with rich text on the clipboard. Expected: the same list of types and sizes.
- [ ] Empty clipboard (run `pbcopy < /dev/null`): after dictation the clipboard is empty again, or at least does not hold the transcript. Record which.
- [ ] Large clipboard (a 20 MB image): restore still works and insertion is not visibly slower.
- [ ] Timing: the restore never happens before the target app has read the paste. In a slow app (Google Docs, Slack) the transcript is inserted, not the old clipboard content. Repeat five times.
- [ ] The user copies something new during transcription (after release, before insertion). Expected: the user's new copy is what ends up on the clipboard. Record the behavior.
- [ ] Universal Clipboard (Handoff on, an iPhone nearby): the transcript does not show up as pasteable on the iPhone after a dictation.

Clipboard managers must not record the transient item. The convention that clipboard managers honor is the `org.nspasteboard.TransientType` and `org.nspasteboard.ConcealedType` pasteboard markers. `PasteInserter` is expected to set them on the transcript item.

- [ ] With Maccy, Raycast clipboard history, Alfred clipboard history, or Paste running, dictate three sentences. Expected: none of the three transcripts appears in the manager's history. Name the manager and version in the results.
- [ ] The restored original item does not appear as a new duplicate entry in the manager's history. If it does, record it: this is cosmetic, not a privacy failure.

## 10. End to end

The core loop: focus a text field, hold the hotkey, speak, release, text is inserted.

- [ ] Run the core loop ten times in a row in TextEdit without touching anything else, one sentence of about ten words each. Expected: ten correct insertions, no errors, no stuck overlay, no restart needed.
- [ ] Measure the time from key release to text on screen with a stopwatch for each of the ten runs and note them. Record the minimum, the median, and the maximum. Ignore the first run after launch in the median if it includes model loading, but record it separately.
- [ ] Run the loop five more times, alternating between two apps (TextEdit and Safari). Expected: text always lands in the app that is frontmost.
- [ ] Leave the app idle for 30 minutes, then dictate. Expected: it works, and the delay is not much worse than the median above. Record it.
- [ ] Dictate on battery with Low Power Mode on. Record the delay.
- [ ] After all of the above, the state is idle, the microphone indicator is off, and `lsof -p "$(pgrep -x Quoth)" | wc -l` is not far above its value after the first dictation (no descriptor leak).

Latency record:

| Run | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Seconds from release to text | | | | | | | | | | |

## 11. Privacy checks

The privacy rule: nothing leaves the machine unless the user picks a cloud backend. With local backends selected the app makes no network requests other than the one-time model download from Hugging Face by WhisperKit and the Sparkle update check (which can be disabled). API keys live only in the Keychain. Audio is never written to disk. History is stored locally and can be cleared or disabled.

Network, with local backends selected and the model already downloaded:

- [ ] Start `nettop -p "$(pgrep -x Quoth)"` in a terminal (or watch Quoth in Little Snitch or LuLu). Dictate ten sentences, open every window, and leave the app idle for ten minutes. Expected: no connections at all. Before v1.0 there is no updater, so the expected count is zero.
- [ ] Cross-check with `lsof -i -a -p "$(pgrep -x Quoth)"` right after a dictation. Expected: no output.
- [ ] On a first run with no model, the only hosts contacted are Hugging Face hosts (`huggingface.co` and its CDN hosts). List every host you saw in the results. Any other host is a failure.
- [ ] After the download completes, relaunch and repeat the first item. Expected: zero connections. No version check, no analytics, no crash reporter.
- [ ] From v1.0: the Sparkle update check is the only additional connection, it goes only to the appcast URL on GitHub Pages, and turning automatic update checks off stops it. The updater issue extends this item.
- [ ] From v0.3: with a cloud backend selected, connections go only to that provider's API host. After switching back to the local backend, the count returns to zero.

Disk:

- [ ] Run the "No audio on disk" checks from section 5 after the full end to end run.
- [ ] Look at everything the app wrote: `ls -laR ~/Library/Application\ Support/Quoth`. Expected: only the JSON stores described in docs/ARCHITECTURE.md (history, dictionary, snippets, once they exist) and nothing else. No transcripts anywhere other than the history store.
- [ ] No transcript text in logs: dictate the distinctive phrase "purple giraffe umbrella", then run `log show --last 15m --predicate 'process == "Quoth"' | grep -i "giraffe"`. Expected: no output.

UserDefaults and secrets:

- [ ] `defaults read io.github.ryan-stoffel.quoth`. Expected: settings only. Nothing that looks like a key: no long random strings, nothing starting with `sk-`, no field named like `apiKey`, `token`, or `secret` with a value. No transcripts.
- [ ] `grep -rIlE '(^|[^a-z])sk-[A-Za-z0-9]{8,}' ~/Library/Application\ Support/Quoth 2>/dev/null`. Expected: no output.
- [ ] `defaults export io.github.ryan-stoffel.quoth - | grep -E 'sk-[A-Za-z0-9]{8,}'`. Expected: no output. The preferences plist is binary, so `grep` on the file itself would skip it.
- [ ] From v0.3: after saving an API key in settings, it is present in Keychain Access under the Quoth service and absent from `defaults read` and from Application Support. After removing the key in settings, the Keychain item is gone.

Demo mode isolation (this protects CI, and works on the skeleton today):

- [ ] Launch with `open DerivedData/Build/Products/Debug/Quoth.app --args -demoMode YES -demoScene popover`. Expected: no microphone prompt, no Accessibility or Input Monitoring request, no Keychain prompt, and zero connections in `nettop`.

## 12. Idle resource use

- [ ] Launch the app, dictate once so the model is loaded, then leave the Mac alone for ten minutes with the popover closed.
- [ ] In Activity Monitor, CPU tab: Quoth shows 0.0 to 0.1 percent CPU while idle, with no periodic spikes. Anything steadily above 1 percent is a failure. Record the value.
- [ ] Energy tab: Energy Impact is about 0 and "Preventing Sleep" is No.
- [ ] Memory tab: record the Memory value before the first dictation (model not loaded), right after it, and after ten minutes idle. Expected: the idle value is stable, not growing. Record whether the model stays resident or is unloaded.
- [ ] Record the same numbers after the ten-run end to end test. Expected: memory after twenty dictations is close to memory after one (no per-dictation leak). A rise of more than about 50 MB needs an explanation.
- [ ] Idle wakeups (add the "Idle Wake Ups" column): low and steady. A listen-only event tap should not cause hundreds of wakeups per second while no keys are pressed.
- [ ] The Mac still goes to sleep on schedule with Quoth running.
- [ ] Skeleton check that applies today: the shell app idles at 0.0 percent CPU and a few tens of MB of memory.

## 13. Later milestones

The features below do not exist yet. Each heading names the milestone and gives the first concrete checks. The issue that builds the feature extends its section with full coverage in the same PR, and moves the section above this heading.

### Cleanup pipeline (v0.2)

Rules are unit tested in `QuothCore` (`FillerWordRemover`, `SelfCorrectionParser`, `SpokenPunctuation`, `PunctuationAndCapitalization`). The manual checks cover real speech, which unit tests cannot.

- [ ] Say "um, so I think, uh, we should ship it". Expected: fillers removed, the rest intact: "So I think we should ship it."
- [ ] Say "let's meet Tuesday, no wait, Wednesday". Expected: only the corrected version is inserted.
- [ ] Say "hello comma world period new line next". Expected: punctuation and a line break, not the spoken words.
- [ ] With cleanup turned off in settings, the raw transcript is inserted unchanged.
- [ ] Optional LLM cleanup with a local model: run the network check from section 11 and confirm zero connections.

### Dictionary (v0.2)

- [ ] Add a custom word that Whisper gets wrong (a surname or a product name). Dictate it. Expected: the dictionary spelling is inserted.
- [ ] Entries survive a relaunch, and live in a JSON file under `~/Library/Application Support/Quoth`.
- [ ] Removing an entry takes effect on the next dictation without a relaunch.

### History (v0.2)

- [ ] Each dictation appears in the History window with the right text and time. Newest first.
- [ ] "Clear history" empties the window and the file on disk: check the JSON store for leftover text.
- [ ] With history disabled in settings, new dictations are not written to disk at all. Verify by reading the file, not only the window.
- [ ] History never contains audio, only text.

### Settings (v0.2)

- [ ] Every setting takes effect without a relaunch, or says that a relaunch is needed.
- [ ] Changing the hotkey: the new hotkey works, the old one stops working, and section 4 passes with the new hotkey. A hotkey that conflicts with a common system shortcut is refused or warned about.
- [ ] Selecting a specific input device overrides the system default, and falls back cleanly when that device is unplugged.
- [ ] Settings survive a relaunch. `defaults delete io.github.ryan-stoffel.quoth` returns the app to defaults without a crash.

### Snippets (v0.3)

- [ ] Define a snippet with a spoken trigger ("my email") and an expansion. Dictate the trigger alone. Expected: the expansion is inserted.
- [ ] Dictate the trigger inside a longer sentence. Expected: expanded in place, surrounding text and spacing intact.
- [ ] A multi-line expansion is inserted with its line breaks in TextEdit, and does not send a message early in Slack.

### Command mode (v0.3)

- [ ] Select a paragraph in TextEdit, hold the command hotkey, say "make this shorter". Expected: the selection is replaced by the result, and one Cmd+Z restores the original.
- [ ] With no selection, command mode does nothing destructive and explains what it needs.
- [ ] The selected text goes only to the configured LLM. With a local LLM, the network check from section 11 shows zero connections.

### Cloud backends (v0.3)

- [ ] With no API key set, choosing a cloud backend explains what is missing. It does not fall back to sending audio anywhere else.
- [ ] With a wrong key, the error names the provider and the cause. With the network off, the error says so, and the app offers the local backend.
- [ ] The key is stored only in the Keychain (section 11), and the settings UI states clearly that audio leaves the machine with this backend.

### Onboarding (v1.0)

- [ ] On a true first run (section 1 reset), the onboarding window opens and walks through microphone, Accessibility, and Input Monitoring, one at a time, each with a working button to System Settings.
- [ ] Each step detects its grant live and advances or shows a check. Quitting midway and relaunching resumes at the first missing permission.
- [ ] Onboarding ends with a working test dictation, and never appears again after completion.

### Updater (v1.0)

- [ ] With an older signed build installed, "Check for Updates" finds the newer release from the appcast on `gh-pages`, verifies the signature, installs it, and relaunches.
- [ ] After the update, all three permissions still work without being granted again (the Developer ID signature is what makes this hold).
- [ ] With automatic checks disabled, `nettop` shows no connection to the appcast host over a full day of use (spot check for ten minutes at minimum).

### Signed release (v1.0)

- [ ] Download the zip from the GitHub release on a Mac that has never run Quoth. Expected: it opens after the normal Gatekeeper dialog, with no "damaged" or "unidentified developer" warning.
- [ ] `spctl -a -vv /Applications/Quoth.app` reports `accepted` and `Notarized Developer ID`. `codesign --verify --deep --strict /Applications/Quoth.app` exits 0.
- [ ] `lipo -archs /Applications/Quoth.app/Contents/MacOS/Quoth` prints `x86_64 arm64`. The app launches on an Intel Mac, where the local backend reports itself unavailable.
