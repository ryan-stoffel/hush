# Research: how Wispr Flow works today, and what that means for Hush

Research date: 2026-09-17. Status of Hush on that date: only the project skeleton exists (menu bar agent app shell, demo mode argument parsing, UI test harness, CI). Every Hush behavior described below is planned, with the milestone named. Nothing here is a claim that a feature works.

## Contents

1. [Purpose and method](#1-purpose-and-method)
2. [Product snapshot](#2-product-snapshot)
3. [Feature inventory](#3-feature-inventory)
4. [Core interaction details](#4-core-interaction-details)
5. [What reviewers praise and criticize, and what that means for Hush](#5-what-reviewers-praise-and-criticize-and-what-that-means-for-hush)
6. [Open-source landscape](#6-open-source-landscape)
7. [Technical findings that shape the build](#7-technical-findings-that-shape-the-build)
8. [Deliberate differences from Wispr Flow](#8-deliberate-differences-from-wispr-flow)
9. [Could not verify](#9-could-not-verify)
10. [Naming](#10-naming)
11. [Sources](#11-sources)

## 1. Purpose and method

Hush is an open-source macOS menu bar app for voice dictation, inspired by tools like Wispr Flow. Before writing feature code we recorded how Wispr Flow behaves today, so that Hush's defaults (hotkeys, overlay behavior, cleanup rules, failure handling) match what users of that category of app already expect, and so that we avoid its known problems.

All pages were fetched on 2026-09-17. Six research passes were run and their results merged here:

| Pass | Sources consulted |
| --- | --- |
| Official site | wisprflow.ai home, /features, /pricing, /privacy, /notetaker, /business, /why-flow, /lab, /whats-new, /data-controls, /blog and individual posts |
| Help center | About 60 articles on docs.wisprflow.ai, text extracted from the raw HTML. The article index is at docs.wisprflow.ai/llms.txt |
| Changelog and UI | wisprflow.ai/whats-new, three official changelog screenshots (v1.4.709 and v1.6.11), the homepage Flowbar.svg asset |
| Independent reviews | TechCrunch, Zapier, zackproser, technovice, tl;dv, Product Hunt, Hacker News, a forensic write-up by Wensen Wu, a Growth Dives onboarding teardown, plus competitor-written comparison pages (Voibe, Spokenly, Willow, Aqua) |
| Open-source projects | GitHub repo pages, raw source files, issues, pull requests, and ADRs for the leading macOS dictation projects |
| Primary technical sources | Apple developer documentation and forums, WhisperKit and Sparkle source at tagged releases, the XcodeGen project spec, the GitHub actions/runner-images README |

Confidence markers. Each finding in the raw data carried a confidence level. Statements below are high confidence unless marked (medium) or (low). Competitor-written pages are never treated as better than medium. Where official help articles contradict each other, both versions are given and the conflict is repeated in [Could not verify](#9-could-not-verify).

Reddit, the New York Times, Wirecutter, Business Insider, Medium, and Podfeet could not be fetched directly. Evidence from Reddit, NYT, Wirecutter, and Podfeet comes only from search snippets and secondary sources. The Business Insider and Medium articles are not used at all.

## 2. Product snapshot

### Products and platforms

Wispr sells two products inside one app: Wispr Flow Dictation and Wispr Flow Notetaker (launched on Mac 2026-08-05 and on Windows 2026-09-15).

| Platform | Requirement |
| --- | --- |
| Mac | macOS 12 or later, separate Apple Silicon and Intel builds, 8 GB RAM recommended. Notetaker needs macOS 13 or later |
| Windows | Windows 10 or 11, x64 only. ARM is not supported |
| iPhone | iOS 18.3 or later. No iPad app |
| Android | Android 13 to 16 phones, launched 2026-02-23 as a floating bubble overlay. Tablets and foldables are unsupported |
| Not supported | iPad, Linux, Chromebooks, virtual machines, remote desktop environments |

Latest desktop version seen: v1.6.721 (2026-09-04). The desktop app is reported to be Electron with a native Swift helper on macOS that handles key monitoring, active app detection, and text injection (medium, from an unofficial Linux port; the official docs confirm only that a separate helper process exists).

Sign-in is mandatory: Google, Apple, Microsoft, SSO, or email and password.

### Pricing tiers and limits

| Tier | Price | Limits and notes |
| --- | --- | --- |
| Free | $0, no card | 2,000 words per week on desktop, 1,000 per week on mobile. Includes 100+ languages, dictionary, snippets, limited Notetaker. Command Mode does not work |
| Pro | $15 per user per month, or $12 billed annually ($144 per year) | Unlimited dictation, Command Mode, shared dictionary and snippets, basic team analytics |
| Growth | $23 per month, or $18 billed annually | SSO/SAML, org-wide HIPAA enforcement, usage reporting, unlimited Notetaker meetings |
| Enterprise | Custom, annual only | SCIM, audit logs, MDM, domain capture, model training locked off |

Other facts:

- Students and educators get 50% off Pro. Trials: 14 days standard, 1 month when referred, 3 months for students.
- The weekly cap resets Sunday at 12 a.m. PT. Unused words do not roll over (medium).
- Some new desktop signups get an 8,000-word first-week bonus instead of a Pro trial (medium).
- One help article describes the post-trial free plan as 1,000 words per week, which conflicts with the pricing page (medium, unresolved).
- There is no lifetime or one-time purchase option. Reviewers complain about this repeatedly.
- Transcription accuracy is stated to be identical across all tiers (medium).

### Cloud-only architecture

- Every dictation requires an internet connection. There is no on-device model and no offline mode. The privacy page says transcription is processed in the cloud for speed and accuracy.
- A forensic report (medium) found audio and context streamed to a Baseten gRPC endpoint. A competitor-compiled subprocessor list (medium) names Baseten for ASR, OpenAI, Anthropic, and Cerebras for formatting, Fireworks and OpenRouter as fallback, and AWS us-east-1. Wispr does not publish the list; it is available only under NDA.
- All data is processed and stored in the United States. There is no end-to-end encryption (audio is decrypted server side), no EU residency, and no bring-your-own-key option (medium).
- The desktop app keeps audio locally with a 14-day retry window.
- Privacy settings live in Settings > Data and Privacy. The old Privacy Mode toggle was renamed and inverted to a model improvement toggle, which is on by default and pre-selected in onboarding. Other toggles: Dictation cloud storage, Local data storage (store, auto-delete every 24 hours, never store; added 2026-04-24), and Context awareness (on by default). Zero data retention means model improvement off plus cloud storage off.
- Compliance claims conflict (medium). Marketing pages state SOC 2 Type II and ISO 27001 certification. The help center security FAQ says SOC 2 Type I and ISO 27001 Stage 1 were completed in April 2026 and Type II is still in its observation period.
- On 2026-08-17 Wispr announced a $280M Series B at a $2B valuation and previewed Canto, its first proprietary speech model. Production rollout status is unknown.

### Latency and accuracy: claimed versus measured

| Item | Vendor claim | Independent or third-party measurement |
| --- | --- | --- |
| End-to-end latency from end of speech | 700 ms budget: under 200 ms ASR, under 200 ms for a fine-tuned Llama cleanup pass, up to 200 ms network. A Baseten case study calls 700 ms a p99 target | About 1.5 s in a fixture test on identical synthetic audio (voice-list.com, 2026-06-10, medium). Competitors report 1 to 2 s (Spokenly) and 1 to 3 s (Aqua) (medium to low) |
| Accuracy | /why-flow claims a 90% zero-edit rate. Canto is claimed to cut word error rate in hard conditions from 30%+ to 5 to 10% | 96.5% in the same fixture test, against 98.0% for Aqua (medium). Wirecutter snippet: 98% (medium). A 97.2% figure circulates without a traceable primary source |
| Speaking speed | 220 wpm against 45 wpm typing | Reviewers report 170 to 184 wpm |
| Streaming | None | Confirmed. Text appears only after release and processing, never while speaking |
| Reliability | 99.9% uptime and a 30% latency reduction year to date, claimed 2026-07-09 | A competitor log (medium) counts 75+ status incidents since 2025-12-18 and a capacity and latency incident between 2026-05-27 and 2026-06-08 with about 5 days 22 hours of logged incident time |

Resource use (medium). The widely repeated figures of about 800 MB idle RAM, 8% CPU, and 8 to 10 s startup trace to competitor posts citing Reddit and Product Hunt users and appear to describe the Windows Electron app. The only first-hand Mac measurement found was about 166 MB and 1.8% CPU during dictation on an M4.

## 3. Feature inventory

Hush milestones, from the project plan: v0.1 (menu bar, hotkey, capture, local transcription, paste insertion), v0.2 (cleanup, dictionary, history, settings), v0.3 (snippets, command mode, cloud backends), v1.0 (onboarding, updater, signed release). "Not scheduled" means there is no milestone yet and the work needs an issue first.

| Feature | Wispr Flow today (Mac defaults) | Hush plan | Milestone |
| --- | --- | --- | --- |
| Push to talk | Hold Fn, speak, release. Falls back to Ctrl+Opt when no Apple Fn key is detected at first run | Same defaults. Fn via a listen-only event tap, Ctrl+Opt offered as a second binding | v0.1 |
| Hands-free | Fn+Space, or double-tap the push-to-talk key from idle or mid-session to lock. Press again to stop. Fallback Ctrl+Opt+Space. The dedicated binding can be deleted | Same: toggle binding Fn+Space plus double-tap lock in `HotkeyStateMachine` | v0.1 |
| Cancel | Esc discards without pasting and leaves the clipboard unchanged | Same | v0.1 |
| Paste last transcript | Cmd+Ctrl+V. Also in the menu bar menu with a preview | Same default. Reads from the local history store | v0.2 |
| Copy last transcript | Cmd+Ctrl+C | Same default | v0.2 |
| Command Mode | Fn+Ctrl (fallback Cmd+Ctrl+Opt). Off by default, paid plans only. Hold, speak the instruction, release. Double-press locks, triple-press dismisses | Same default hotkey. Reads the selection, sends speech as the instruction to the `LLMCleaner`, replaces the selection. No plan gate | v0.3 |
| Session limit | 20 minutes per desktop session, warning at 19 minutes, auto-stop then transcribe, with a recover action (medium: older articles still say about 6 minutes) | Same 20-minute cap and 19-minute warning. WhisperKit handles long audio with VAD chunking | v0.1 (cap), v0.2 (warning UI) |
| Status overlay | Flow Bar pill. Hidden by default on new installs. Bottom center. States: resting, recording, processing. White waveform bars | Non-activating overlay panel with waveform and elapsed time. Shown only while listening or transcribing. Never takes focus | v0.1 |
| Text insertion | Clipboard write, synthetic Cmd+V, then restore the previous clipboard. Marked concealed on macOS. On failure the text stays on the clipboard and a notice points to paste last | Paste insertion with snapshot, transient markers, layout-aware V key, delayed and guarded restore. Accessibility insertion only where a read-back confirms it | v0.1 (paste), AX path follows |
| Filler removal and auto punctuation | Smart Formatting, on by default. Removes fillers, punctuates, capitalizes, builds lists | Rule-based `CleanupPipeline` stages, no network | v0.2 |
| Backtrack | Self-correction on "actually", "scratch that", "never mind", or a plain restatement | `SelfCorrectionParser` stage for the explicit triggers. Restatement handling needs the optional LLM stage | v0.2 |
| Spoken punctuation and line commands | Named marks, "new line", "new paragraph". Work even with Smart Formatting off | `SpokenPunctuation` stage, always on | v0.2 |
| Auto Cleanup level | None, Light (default), Medium. A legacy High now maps to Medium (medium: a screenshot still shows four cards) | Cleanup level setting with a verbatim option. The raw transcript is kept in history so an edit can be undone | v0.2 |
| Dictionary | Vocabulary boosts and misspelling replacement rules. Stars, sort, CSV import, team sharing, cloud sync. No export | Local `DictionaryStore` (JSON). Vocabulary feeds WhisperKit prompt tokens. Replacement rules run in `DictionaryApplier`. Import and export | v0.2 |
| Dictionary auto-learn | Watches the text box it pasted into and adds changed spellings. On by default | Not scheduled. If built, it will be opt-in and local only | Not scheduled |
| Snippets | Spoken trigger up to 60 characters, expansion up to 4,000. Whole-word, case-insensitive match. Static text. Rich text since 2026-07-29 | Local `SnippetStore`, same matching rules, plain text | v0.3 |
| Styles (per-app tone) | Formal, Casual, Very Casual, Excited, chosen per category (Personal, Work, Email, Other). Category detected from the app, or the URL in browsers. English only | Not scheduled. Any per-app behavior will use the frontmost bundle id only, never URLs | Not scheduled |
| Languages | 100+ languages, auto-detect on by default, per-session detection. A picker appears on the pill when 2 or more are selected | Whisper multilingual models. Language setting and auto-detect through WhisperKit `DecodingOptions` | v0.1 (single language), v0.2 (setting and auto-detect) |
| Whisper mode | A marketing name, not a toggle. Quiet speech is handled by the model and depends on mic distance | No feature needed. Document mic guidance | None |
| History | Hub Home, grouped by day, searchable, local per device, audio playback for 14 days, undo AI edit | Local `HistoryStore`, grouped by day, searchable, can be cleared or disabled. Audio is never written to disk, so no playback | v0.2 |
| Scratchpad | Floating rich-text notepad, Opt+S, cloud sync | Not planned | None |
| Microphone selection | Auto-detect or a ranked device list. AirPods flagged. Virtual devices hidden by default | Device picker in the Audio settings tab, following the system default by default | v0.2 |
| Sounds | Start ping and stop sound behind a Sound Effects toggle. Optional mute of other audio while dictating, off by default on Mac | Start and stop sounds with a toggle, in the Audio settings tab | v0.2 |
| Settings | Modal with General, System, Vibe coding, Experimental, and Account groups | Tabs: General, Hotkeys, Audio, Transcription, Cleanup, Dictionary, Snippets, Privacy | v0.2 (Snippets tab in v0.3) |
| Shortcut editor and validation | Max 3 keys, modifier required, no left plus right mix, no Caps Lock, no duplicates, reserved OS shortcuts rejected, up to 4 bindings per action | Same validation rules in HushCore, unit tested | v0.2 |
| Onboarding | About 16 steps, 5 to 8 minutes: sign-in, permissions, questions, mic test, shortcut, languages, practice demos, data choice | Welcome, Microphone, Accessibility (and Input Monitoring). No sign-in. No survey | v1.0 |
| Launch at login | On by default. Reviewers report it re-adds itself to login items | Off by default. `SMAppService.mainApp`, toggle reads live status | v1.0 |
| Auto-update | Built in. Restarts are deferred until idle | Sparkle 2.10, check can be disabled | v1.0 |
| Cloud transcription | The only mode | Optional OpenAI and Deepgram backends, keys in the Keychain | v0.3 |
| Context awareness | Reads app, surrounding text, on-screen text, and a screenshot, and sends it with each dictation. On by default | Not planned as a cloud feature. Insertion needs only the focused element and selection, read locally | None |
| Mouse button bindings | Middle click and Mouse 4 to 10. Bound clicks are swallowed | Not scheduled | Not scheduled |
| Transforms, Insights, leaderboard, team sharing, Notetaker, MCP connector, IDE file tagging | Present | Not planned. See [Deliberate differences](#8-deliberate-differences-from-wispr-flow) | None |

## 4. Core interaction details

### Push to talk

- Click into a text field, hold Fn, start speaking after the ping or once the white bars move, release. The cleaned text is pasted. No text appears while speaking.
- If no Apple Fn key is detected at first run, the default becomes Ctrl+Opt. The help center recommends Ctrl+Opt or Opt+Cmd for external keyboards and suggests keeping Fn plus Ctrl+Opt as a second binding for docked use. The Apple Fn key fires only from Apple keyboards.
- Releasing almost immediately produces a short-press or no-audio notice and no paste. A tap instead of a hold produces a notice telling the user to hold the key.
- Wispr discards a small amount of audio at the start of each recording, so a brief pause before speaking helps.
- Clicking the pill during push to talk ends the session.
- Left or right mouse click while recording cancels the recording.
- Key presses are ignored while the app is initializing, stopping, processing, or retrying.
- Keyboard shortcuts are never suppressed: other apps still receive them. Only bound mouse buttons are swallowed.

Hush (v0.1): identical hold semantics. The listen-only tap means the hotkey always reaches the frontmost app too, which matches this behavior.

### Hands-free and double-tap lock

- Three ways to start: the hands-free shortcut (Fn+Space, or Ctrl+Opt+Space without Fn), a click on the center of the pill, or a quick double-tap of the push-to-talk shortcut. The double-tap works from idle or mid-session and locks the session into hands-free.
- Stop and paste: press the hands-free shortcut again or click the stop control. Discard: click X or press Esc.
- The center of the pill is deliberately not clickable during hands-free, so a stray click cannot end a long session.
- For multi-key push-to-talk shortcuts, all keys must be pressed together, twice.
- The dedicated hands-free binding is optional since August 2026. Deleting it sticks, and the shortcut editor shows a live hint for the double-tap built from the user's own keys.
- A session auto-stops on the 20-minute limit, on no audio detected, on mic acquisition failure, or on loss of internet.
- The double-tap window and the minimum hold duration are not documented anywhere. Open-source projects use 150 ms to 500 ms hold thresholds (see section 6).

Hush (v0.1): `HotkeyStateMachine` implements hold and toggle. The double-tap window and minimum hold will be constants in HushCore, chosen from the open-source range and covered by unit tests.

### Flow Bar pill

- A small dark floating pill that shows resting, recording, and processing states. White moving bars while listening are the visual equivalent of the start ping.
- Hidden by default on new installs. It can be shown at all times or hidden for one hour. The docs disagree on the exact name and location of the visibility setting.
- Default position is bottom center. Until 2026-07-09 it was fixed there and covered controls such as Gmail's send button and the Dock, which was the top complaint in a public feedback thread. It can now be dragged to drop zones on the bottom, left, or right edge, turns vertical on a side edge, remembers its position, and Esc cancels a drag.
- Hover enlarges it and shows the current push-to-talk shortcut and the mic in use. With 2 or more languages selected, hover also shows a names-only language picker.
- While recording it shows a cancel (X) control, waveform bars, and a finish control. Mac docs describe the finish control as a stop square. The marketing SVG and the Windows text use a checkmark.
- Marketing asset dimensions (medium, not measured in the app): 97 by 28 pill, fill #1A1A1A, 1 px stroke #4D4A42, corner radius 13.5, ten rounded bars 2.25 px wide colored #FFFFEB, 18 px circular buttons.
- Third-party estimate (medium): the idle pill is about 70 px wide inside a transparent window of about 440 by 300.
- Transparent areas pass clicks through to the app underneath. Buttons and menus capture clicks.
- The right-click menu offers Settings, Microphone, Transcript history, and Paste last transcript. Articles disagree on whether it also offers language switching and the hide-for-one-hour item.
- It appears in screen shares and screenshots unless a setting hides it. Some full-screen modes hide it.
- No source documents a case of the pill stealing keyboard focus. The Scratchpad panel is explicitly described as not stealing focus.
- The look of the processing state and any distinct Command Mode visual are not documented.

Hush (v0.1): the overlay is a display-only panel that appears only while listening or transcribing, so there is no always-on pill to cover controls. It ignores mouse events, which makes click-through total. A persistent or draggable pill is not planned.

### Command mode

- Off by default. Enabled in Settings > Experimental. Requires a paid plan or trial. On a free plan the shortcut does nothing.
- Hold Fn+Ctrl, speak the instruction, release to run. Esc or Backspace cancels. A very short press dismisses. Double-press locks hands-free, triple-press dismisses.
- Text-editing commands need a selection or surrounding text. With neither, nothing happens, and failed edits show no error.
- When spoken inside a normal dictation, editing commands must start with a "Hey Flow" variant. Spoken triggers are English only. The hotkey works in any language.
- Web-search commands start with "ask", "search", or "hey" plus a service name (Google, Perplexity, ChatGPT, Claude). The app opens that site with the dictated query and appends any selected text.
- Reviewers call Command Mode glitchy (medium, Zapier).
- Transforms (beta, 2026-05-01) is a separate feature: Opt+1 Polish, Opt+2 Prompt Engineer, Opt+O View Diff, up to 9 slots, selection of 1 to 1,000 words.

Hush (v0.3): hotkey only, no spoken wake phrase, no web-search commands. When there is no selection, Hush will say so instead of failing silently.

### Backtrack and auto-edits

- Smart Formatting is on by default (Settings > System > Extras). It covers grammar, punctuation, capitalization, filler removal, paragraph structure, and lists. It does not fix misheard words. Turning it off gives raw text and disables Backtrack.
- Backtrack triggers: "actually", "scratch that", "never mind", or restating. The whole dictation is used as context. "Coffee at 2 actually 3" becomes "coffee at 3". A non-corrective "actually" is kept.
- Blending: mid-sentence insertions are lowercased unless the first word is a proper noun. Leading and trailing spaces are added as needed. Trailing punctuation is stripped when the text after the cursor continues the sentence. When an app returns no surrounding text, new-sentence behavior is used.
- Messaging apps: the trailing period is dropped for dictations of up to two sentences. Exclamation and question marks are kept.
- Lists: "one ... two ..." or "first ... second ..." produces a numbered list. Spoken numbers become digits.
- Spoken punctuation includes period or full stop, comma, question mark, exclamation point, colon, semicolon, dash, quotation mark, apostrophe, asterisk, ampersand, percent sign, ellipsis, slash, backslash, underscore, hashtag, tilde, at sign, angle brackets, parentheses, plus, minus, equals, trademark, copyright, and degree signs.
- Line commands: "new line", "next line", "line break", "skip a line". Paragraph commands: "new paragraph", "start a new paragraph". These work regardless of the Smart Formatting setting.
- "Press enter" at the very end of a dictation presses Enter after the paste. It is opt-in, experimental, and disabled in Command Mode.
- Auto Cleanup levels: None (raw), Light (default: fillers and grammar), Medium (clarity and concision, may reword). Cleanup is skipped for very short or very long text. Over-editing is the most common quality complaint, and Wispr shipped a fix for it on 2026-07-09.
- Undo: Cmd+Z right after the paste, or an undo item on the history row that shows the raw version.

Hush (v0.2): the rule stages run in a fixed order (`FillerWordRemover`, `SelfCorrectionParser`, `SpokenPunctuation`, `PunctuationAndCapitalization`, `DictionaryApplier`, `SnippetExpander`, then the optional `LLMCleaner`). The default is conservative: rules only, no rewording. Verbatim is a first-class option. The raw transcript is kept with each history entry.

### Dictionary and auto-learn

- Two entry kinds: a vocabulary word that boosts recognition, and a misspelling rule that replaces text after transcription. One replacement per word. Entries need at least one letter or digit. Duplicates are rejected.
- Changes take effect immediately and sync across devices. Personal entries win over team entries.
- Starred words get priority. Sort by starred, newest, oldest, or alphabetical. Usage also affects ranking.
- Length limit: 60 characters in three articles, 30 in two others, with a note that at most 200 words sync at a time.
- Bulk import: CSV with one column (words) or two (misspelling, correction), under 3 MB and 1,000 items. There is no export.
- A few default entries are seeded (for example "btw" to "by the way").
- Wispr's own docs warn that very large dictionaries reduce accuracy and suggest trimming to about 200 terms (medium).
- Auto-learn: with auto-add enabled, the app monitors the text box it pasted into. If the user changes the spelling of a transcribed word, the new spelling is added. Auto-added words carry a sparkle badge. It cannot read secure fields and stops when focus is lost.

Hush (v0.2): manual dictionary with both entry kinds, import and export. Vocabulary is passed to WhisperKit as prompt tokens, which the decoder trims to the last 111 tokens, so the practical vocabulary budget is small and the most relevant terms must be chosen. Auto-learn is not scheduled, because it requires watching a text field after the paste.

### Snippets

- Say the trigger inside normal dictation and the expansion is inserted in place.
- Trigger up to 60 characters, expansion up to 4,000. Matching is case-insensitive and whole-word. Inside a sentence the trigger must have no surrounding punctuation. If the whole dictation is just the trigger, a trailing period does not block it.
- Exact duplicate triggers are blocked. Near-duplicates save with a notice.
- Static text only, no variables. Rich text since v1.6.288.
- Bulk import is a JSON array of phrase and replacement pairs, under 3 MB and 1,000 items.
- Cmd+Enter saves.

Hush (v0.3): same limits and matching rules, plain text, import and export.

### Styles and per-app tone

- Four categories: Personal messages, Work messages, Email, Other.
- Styles: Formal (capitals and punctuation, all categories), Casual (capitals, less punctuation, all), Very Casual (no capitals, less punctuation, Personal only), Excited (more exclamation marks, all except Personal).
- Default mapping: Personal is WhatsApp, Telegram, Discord, Instagram, Signal. Work is Slack, Microsoft Teams, LinkedIn. Email is Gmail, Superhuman, Outlook, Apple Mail. Everything else is Other. Users can assign more apps.
- The category is detected from the active app, and from the website URL in browsers.
- No style is pre-selected on desktop. Styles are optimized for English.
- Outside messaging apps, Casual drops periods for dictations up to about ten sentences and Very Casual always drops them.

Hush: not scheduled. URL-based detection conflicts with the no app or URL tracking commitment in section 5.

### Languages and auto-detect

- More than 100 languages (the help center cites 104 to 105). Auto-detect is on by default. Users can instead select specific languages, with 2 to 3 recommended.
- Detection is per session, not per word. Switching languages inside a sentence is not supported.
- Highest accuracy: English, Spanish, Portuguese, French, Russian, German, Italian, Dutch, Japanese, Turkish, Polish, Catalan.
- Some variants exclude each other (US, British, and Canadian English; German and Swiss German; Simplified and Traditional Chinese; Hindi and romanized Hinglish).
- Languages are pre-filled from the system locale during onboarding. The app interface language is a separate setting.

Hush (v0.2): language picker and auto-detect in the Transcription tab. Per-session detection matches how Whisper works.

### Whisper mode

There is no toggle. The help center says whispering simply works and that quality depends on mic distance. It discourages AirPods and earbuds, recommends close mics, and recommends selecting the mic manually. Hush needs no feature here.

### History, Scratchpad, and notes

- History lives on the Hub Home page: grouped Today, Yesterday, then by date, searchable, with a stats card (streak, average WPM, total words). It is local per device and does not sync (medium).
- Clicking a row copies it. The row menu offers audio playback and a .wav export for 14 days, report, undo or redo AI edit, retry, and delete. One article says desktop has no per-transcript delete (medium, conflicting).
- Failed rows show a reason (silent audio, interrupted, no microphone, dismissed) and can be retried while the audio is still on disk.
- Storage options: store locally (default), auto-delete every 24 hours, never store. Never store disables history.
- Scratchpad (formerly Notes, beta since 2026-05-01) is a floating multi-tab rich-text notepad opened with Opt+S, with cloud sync, version history, and image paste. It does not steal focus. It doubles as a place to dictate when an app refuses the paste.

Hush (v0.2): a History window, grouped by day and searchable, stored as local JSON, with clear and disable options. No audio is kept, so there is no playback and retry is not possible after the buffer is released. No Scratchpad.

### Onboarding sequence

Official Mac sequence:

1. Install from the DMG. The menu bar icon appears on launch.
2. Sign in through the browser.
3. Permissions page: a microphone card, then an accessibility card. The page advances automatically as each grant is detected. If a permission was denied earlier, the button opens the matching System Settings pane.
4. Intro screens.
5. Questions about the user.
6. Privacy notice.
7. Microphone test with rising bars and a device dropdown.
8. Shortcut step, offering only Push to talk and Hands-free.
9. Dictation languages.
10. Practice demos in mock Slack, email, and list windows, each with a Skip button.
11. Data choice (model improvement on or off).
12. A ready notification that opens the Hub.

A skip prompt shortens this to permissions, mic test, shortcut, and language. Progress is saved if the user quits. Shortcuts stay inactive until the dictation step. A third-party teardown (medium) counts about 16 steps over roughly 8 minutes. Reviewers still describe the time from install to first dictation as short, because there is no model picker.

Hush (v1.0): Welcome, Microphone, Accessibility and Input Monitoring, then done. Same auto-advance and open-the-right-pane behavior. The one step Hush adds is the one-time model download.

### Permissions

- Wispr requires Microphone and Accessibility. Accessibility drives hotkey monitoring, the paste, and context reading. Without it, dictation fails entirely, not only the paste. Screen Recording is not required for dictation.
- The app re-checks permissions when brought to the foreground, and notifies and opens the right pane when one is revoked.
- After an OS or app update, the documented fix is to toggle the permissions off and on, or remove and re-add the app in the Accessibility list.
- Secure Keyboard Entry held by another app (1Password, Terminal with the option checked, a focused password field) blocks Fn+Space and Esc, while modifier-only hold-to-talk and double-press Fn keep working.

Hush (v0.1 for the checks, v1.0 for the onboarding UI): Microphone for capture, Input Monitoring for the listen-only tap, Accessibility for the synthetic Cmd+V and the AX API. See the permission matrix in section 7.

### Settings categories

Wispr's settings open as a modal over the Hub with two groups (medium):

- Settings group: General (Shortcuts, Microphone, Languages, App language), System (Launch at login, Show Flow Bar, Show in dock, Sound, Notifications, Extras with Smart Formatting and auto-add to dictionary, Reset), Vibe coding (Variable Recognition, IDE File Tagging), Experimental (Command Mode, Press Enter, Bulk Import; paid only).
- Account group: Account, Team, Plans and Billing, Data and Privacy.

The Hub sidebar is Home, Insights, Dictionary, Snippets, Style, Transforms, Scratchpad, Notetaker, then Settings and Help.

The menu bar icon menu contains: open the app, paste last transcript (with a preview, greyed out when empty), Shortcuts, Microphone, Languages, help, support, and feedback.

Hush (v0.2): one Settings window with tabs General, Hotkeys, Audio, Transcription, Cleanup, Dictionary, Snippets, Privacy. No account group.

### Shortcut validation rules

- At most 3 keys.
- At least one modifier (Ctrl, Cmd, Opt, Shift, Fn) or a valid mouse button.
- Left and right variants of the same modifier cannot be combined.
- Caps Lock is not allowed.
- The combination must be unique across all actions.
- Reserved OS shortcuts are rejected. On Mac: Cmd with C, V, X, Z, A, Q, W, R, T, P, N, O, S, M, H, F, G; Cmd+Space; Cmd+Tab; Cmd+Shift+3, 4, 5; Ctrl with arrows; Ctrl+A, E, K; Fn+F11 and Fn+F12; Alt+Backspace; Cmd+Shift+R.
- Checks run in this order: reserved, duplicate, modifier, key count, left and right mix.
- Up to 4 bindings per action. Cancel allows 1. Core actions must keep at least one binding (with the documented exception that the hands-free binding can be deleted because the double-tap remains).
- The app warns when the hands-free shortcut is a subset of the push-to-talk shortcut.
- Bindings save immediately, are stored per device, and do not sync. Reset to default has no undo.

Hush (v0.2): the same rules and the same check order, as pure functions in HushCore with unit tests.

### Sounds

- A start ping plays when recording begins, and there is a stop sound. Both sit behind a Sound Effects toggle in Settings > System > Sound.
- "Mute music while dictating" is off by default on Mac. It mutes the default output device on start and restores it on stop, only if audio was actually playing. If the user had already muted, it stays muted.
- The actual sound design (pitch, duration, whether start and stop differ, any error sound) is not documented.

Hush (v0.2): short start and stop sounds with a toggle. Muting other audio is not scheduled.

## 5. What reviewers praise and criticize, and what that means for Hush

### Praise

- It works in any text field, across dozens of apps. One long-term user logged 182,718 words across 36 apps.
- Auto-edits: filler removal, backtracking, list formatting. A Wirecutter snippet calls its formatting the cleanest of the apps it tested (medium).
- Personal dictionary, snippets, per-app tone, IDE awareness, quiet-speech handling, cross-device sync.
- Short path from install to first dictation. No model picker, no modes.
- It keeps up with fast speech and handles a wide range of accents (medium).
- Product Hunt: 4.7 out of 5 from 78 reviews.

### Criticism

- Cloud only. No offline mode, no model choice, no bring-your-own-key, no Linux app.
- Privacy incidents:
  - 2025: a user found screenshot uploads through Context Awareness and was banned. The CTO later apologized, and training use became opt-in (medium, competitor-compiled but independently confirmed by a second source).
  - April 2026 (medium, read only in the author's own write-up): a forensic analysis of Mac v1.4.752 reported a system-wide event tap that actively filters all keystrokes, foreground app and browser URL tracking (1,688 events in 30 hours), accessibility-tree traversal including full text box contents, a 694 MB local database holding 3,404 dictations and 198 MB of audio, hourly metadata uploads that continued with data sharing off, four telemetry services with 1,183 analytics events, and a weakened hardened runtime. The same author hit a stuck-modifier bug: a missed key-up caused 145 spacebar presses to be swallowed over about 10 minutes.
  - June and August 2026: staff publicly showed per-user and aggregate dictation analytics (medium).
- Reliability and latency degraded in 2026, with a long capacity incident in late May and early June. Wispr's changelog acknowledged infrastructure strain, broken audio compression, and language mis-routing.
- Auto Cleanup over-edits: it rewrites instead of transcribing, and it adds a period after short fragments (medium).
- Heavy resource use and slow startup in widely repeated reports, and the app re-adds itself to login items (medium).
- The pill covered UI until it became movable in July 2026.
- Paste failures in secure fields, remote desktops, some terminals, and after macOS updates. A Flutter issue names Wispr Flow among the apps whose synthetic Cmd+V loses its Command modifier in Flutter macOS apps.
- Subscription-only pricing and a 20-minute session cap.

### What Hacker News asks of a local alternative

A Show HN thread for an open-source alternative drew 277 points and 132 comments. Requests: flexible push-to-talk bindings, streaming text while speaking, LLM post-processing for names and technical terms, swappable models, fully offline operation, and latency under one second. Commenters warned that an open-source app that still calls cloud APIs by default is not private. One author reported local LLM cleanup taking 5 to 10 s against under 1 s on a hosted API, which is why Hush treats the LLM stage as optional and keeps the default cleanup rule-based.

### Design commitments for Hush

These follow directly from the criticism above. They are commitments for the build, not shipped behavior.

1. Local first. On-device transcription is the default. With local backends selected the app makes no network requests other than the one-time model download from Hugging Face by WhisperKit and the Sparkle update check, which can be disabled.
2. Listen-only event tap. The tap observes `flagsChanged` and `keyDown` and never filters or swallows events. A listen-only tap cannot cause a stuck-modifier failure in other apps and is not exposed to the active-tap system hang described in section 7.
3. No app or URL tracking. The frontmost bundle id is read at insertion time to pick an insertion strategy and is not logged as activity. Browser URLs are never read.
4. No telemetry. No analytics SDKs, no crash reporters that phone home, no usage uploads.
5. No screen capture and no accessibility-tree traversal. Insertion touches only the focused element and its selection.
6. Audio is never written to disk. History is local, and can be cleared or disabled. API keys live only in the Keychain.
7. Low idle resource use. A native AppKit and SwiftUI agent app with no Electron runtime. No polling loops while idle beyond a cheap tap health check. Aspirational targets from vendor claims (low): start capture in under 50 ms, paste in under 1 s, idle under 100 MB.
8. Conservative cleanup. Rules only by default, verbatim available, raw transcript kept for undo.
9. Reliable insertion with a recovery path. Guarded clipboard restore and a paste-last-transcript hotkey.
10. Launch at login is off by default and the app never re-registers itself after the user turns it off.
11. No persistent overlay. The indicator is visible only during a session.

## 6. Open-source landscape

Star counts are the rounded values rendered on github.com on 2026-09-17. The GitHub API was rate-limited, so none are exact.

| Project | Stars | License | Stack | Insertion technique | Lessons for Hush |
| --- | --- | --- | --- | --- | --- |
| Handy (cjpais/Handy) | 31.8k | MIT | Tauri, Rust, React. Whisper GGML and Parakeet V3. Cross-platform | Clipboard plus Cmd+V through Enigo with pre and post delays. A beta mode publishes a pasteboard promise and restores the old clipboard only after the first read | The fixed-timer restore pastes the old clipboard under load. The read receipt can be triggered early by clipboard-sync helpers. Fn bindings never fire on non-Apple keyboards, so warn and offer a fallback |
| FluidVoice (altic-dev/FluidVoice) | 11.6k | GPLv3 | Swift, SwiftUI, macOS 15+. Eight speech models | Clipboard paste is the default since March 2026, with transient and auto-generated pasteboard markers, Cmd+V posted to the target pid, restore after 500 ms. Unicode typing and AX splicing exist as fallbacks | Made paste the default over direct typing. Releasing an unrelated modifier re-armed a modifier-only hotkey. The tap was found disabled and a 30 s health check was too slow. A force-unwrap on a nil clipboard read crashed in terminals |
| OpenWhispr (OpenWhispr/openwhispr) | 8.3k | MIT | Electron, React, native Swift helpers. whisper.cpp, Parakeet, cloud BYOK | Native helper resolves the key code for "v" with `UCKeyTranslate` against the current layout, then posts Cmd+V | Layout-aware V lookup fixes Dvorak, Colemak, AZERTY, QWERTZ. Pressing any key during a bare-Fn hold must cancel the recording (Fn plus arrows is Home, End, Page Up). 150 ms hold threshold. Fn default with an F8 fallback |
| VoiceInk (Beingpax/VoiceInk) | 6.4k | GPLv3 | Swift, SwiftUI, macOS 14.4+. whisper.cpp, Parakeet, cloud | Clipboard plus Cmd+V via CGEvent, optional AppleScript path. Full pasteboard snapshot, a session id type, restore after at least 250 ms. No AX insertion | Restore-before-paste bug. Fixed key code 9 broke Neo2 and Dvorak. Auto-Enter 50 ms after Cmd+V raced the paste in terminals. Transcripts leaked into clipboard managers. Hybrid hotkey: hold of 0.5 s or more is push to talk, shorter toggles |
| Whispering (EpicenterHQ/epicenter) | 4.8k | AGPL-3.0 | Svelte, Tauri | Clipboard paste | Dropped bare-Fn and modifier-only hotkeys entirely (ADR-0117). Keeps an event tap only as a liveness check: after a macOS update a stale Accessibility grant still reports trusted but silently drops Cmd+V, so it leaves the text on the clipboard instead |
| OpenLess (Open-Less/openless) | 3.6k | AGPL-3.0 | Tauri 2, Rust | Streams text at the cursor, clipboard fallback | Streaming output is possible, with a fallback (medium) |
| Ghost Pepper (matthartman/ghost-pepper) | 3.2k | MIT | Swift. WhisperKit, FluidAudio, local Qwen cleanup | Paste | Hold Control to talk. Proof that WhisperKit plus a small local LLM is viable (medium) |
| Hex (kitlangton/Hex, rewritten at anomalyco/hex) | 2.9k legacy, 215 rewrite | MIT | Legacy: Swift, TCA, WhisperKit, Parakeet. Rewrite: Rust | Polls `changeCount` up to 150 ms to confirm the write, then tries Cmd+V (layout-aware through the Sauce library), then an AppleScript click on the Paste menu item, then AX `kAXSelectedTextAttribute`. Restore after 500 ms | Hold or double-tap to lock. 0.3 s threshold for modifier-only hotkeys, 0.2 s minimum key time otherwise. Other keys within the threshold discard the session |
| OpenSuperWhisper (Starmel/OpenSuperWhisper) | 2.9k | MIT | Swift, whisper.cpp, Parakeet. Apple Silicon only | Auto-paste (source not read) | Uses a listen-only session tap on `flagsChanged`, Fn identified by key code 63 plus the secondary-Fn flag, re-enabled on timeout. It does not handle other keys during the hold, which is a gap to avoid |
| FreeFlow (zachlatta/freeflow) | 2.7k | MIT | Swift. Cloud first (Groq) | Pasteboard write plus Cmd+V. Restore delay raised from 150 ms to 1.0 s after a race. Restores when `changeCount` is unchanged or the clipboard still equals the transcript | The `.function` flag is set on arrow, navigation, and F-keys even when Fn is not held, so any arrow key started a recording. Track Fn only from `flagsChanged` with key code 63. Universal Clipboard and browsers bump `changeCount` in the background |
| TypeWhisper (TypeWhisper/typewhisper-mac) | 1.8k | GPLv3 plus commercial | Swift, SwiftUI, macOS 14+. WhisperKit and many engines | Auto-paste | Per-app profiles, dictionary with auto-learn, local REST API. Shows the scope creep to avoid early |
| Amical (amicalhq/amical) | 1.5k | MIT | Electron plus Swift helper. Whisper, Ollama | Not inspected | (medium) |
| Muesli (Muesli-HQ/muesli) | 1.3k | MIT | Swift | Cmd+V paste | Modifier-key hotkeys including Fn (medium) |
| MacParakeet (moona3k/macparakeet) | 653 | GPL-3.0 | Swift 6, Parakeet v3, macOS 14.2+ | Not inspected | Default hotkey is Fn hold with a separate hands-free shortcut, the same shape as Hush (medium) |

Spokenly is sometimes listed as open source. Its own site says it is not, so its internals cannot be inspected.

Cross-cutting conclusions:

- Every major project defaults to clipboard plus synthetic Cmd+V. None default to AX insertion. AX and Unicode typing exist only as fallbacks.
- Restore delays in the wild: 250 ms (VoiceInk minimum), 500 ms (Hex, FluidVoice), 1.0 s (FreeFlow).
- Hold thresholds in the wild: 150 ms (OpenWhispr), 200 to 300 ms (Hex), under 300 ms short press (TypeNo), 500 ms (VoiceInk hybrid).
- Gaps a new project can fill (medium): Handy has no built-in cleanup, VoiceInk is Apple Silicon only and GPL, FreeFlow calls cloud APIs by default. An MIT-licensed, native, local-by-default app with rule-based cleanup is not well covered. The field is crowded (30+ Show HN posts in 2025 and 2026), so the differentiation has to be real.

## 7. Technical findings that shape the build

### WhisperKit: rename and API

- The repository was renamed on 2026-05-01. `github.com/argmaxinc/WhisperKit` redirects to `github.com/argmaxinc/argmax-oss-swift`. The SwiftPM product is still named `WhisperKit`.
- Latest release: v1.1.0 (2026-08-06). Hush will pin `from: "1.1.0"` when the dependency is added by the v0.1 transcription issue, because earlier versions returned empty transcriptions when `promptTokens` were set, and the v0.2 dictionary will use prompt tokens.
- The package uses swift-tools 5.10 and declares macOS 13, while the README requires macOS 14 and Xcode 16. This matches Hush's macOS 14 minimum. Its only external dependency is swift-argument-parser.
- Transcription signature at v1.1.0:

  ```swift
  open func transcribe(
      audioArray: [Float],
      decodeOptions: DecodingOptions? = nil,
      callback: TranscriptionCallback? = nil,
      segmentCallback: SegmentDiscoveryCallback? = nil
  ) async throws -> [TranscriptionResult]
  ```

  Input is 16 kHz mono Float samples, which is exactly what `AudioCaptureService` is specified to produce. It returns an array. The single-result overloads were removed in v1.0.0. Join with `results.map(\.text)`. `TranscriptionResult` is a class, and the top-level `WhisperKit` class is not yet `Sendable`.
- Init is `try await WhisperKit(WhisperKitConfig(model: ...))`. With `model` nil, the device-recommended model is downloaded from the Hugging Face repo `argmaxinc/whisperkit-coreml` and cached. `prewarm: true` halves peak memory during Core ML specialization at about twice the load time.
- README-recommended models: `large-v3-v20240930_626MB` for accuracy, `large-v3-v20240930_turbo` for speed on macOS, `tiny` for debugging.
- The window is 30 s (480,000 samples). Longer audio uses `decodeOptions.chunkingStrategy = .vad`, which the 20-minute session cap depends on.
- Auto-detect: set `detectLanguage: true` with `language` nil. It defaults to the inverse of `usePrefillPrompt`, so it must be set explicitly. The standalone detection method for sample arrays is still misspelled `detectLangauge(audioArray:)` in v1.1.0.
- Custom vocabulary: encode the prompt text with `whisperKit.tokenizer`, drop special tokens, assign to `options.promptTokens`. The decoder keeps only the last 111 tokens.
- v1.0.0 renamed `supressTokens` to `suppressTokens`.

### Intel is unsupported by WhisperKit

The maintainers state that Intel Macs are unsupported (M1 and newer only). Reported Intel failures are runtime crashes in the feature extractor and mel spectrogram. `Package.swift` has no architecture restriction, so an x86_64 build may compile, but this was not verified. Decision: Hush builds universal, and on Intel the local backend reports itself unavailable. Intel users need a cloud backend (v0.3).

### Sparkle 2.10

- Latest: 2.10.0 (2026-09-13). Versions 2.9.5 and 2.9.6 were security fixes, so nothing older than 2.10.0 should be used. Minimum macOS is now 12. CocoaPods support was removed. The SwiftPM package is a binary target.
- Required Info.plist keys: `SUFeedURL`, `SUPublicEDKey`, and an incrementing `CFBundleVersion`. Optional hardening: `SURequireSignedFeed`, `SUVerifyUpdateBeforeExtraction`.
- `generate_appcast` accepts the private key on stdin with `--ed-key-file -`, which suits CI secrets. Archives should be created with `ditto -c -k --sequesterRsrc --keepParent`. Never codesign with `--deep`.
- For an agent (LSUIElement) app, implement the gentle reminders delegate methods (`supportsGentleScheduledUpdateReminders` and related) so scheduled update alerts do not steal focus.
- Hush is not sandboxed (it posts events and uses the AX API), so none of the Sparkle XPC service keys are needed.
- Sparkle is added in the v1.0 milestone, not before.

### Fn detection and the permission matrix

| API | Permission it needs | Notes |
| --- | --- | --- |
| `CGEventTap` listening to keyboard events | Input Monitoring. Check with `CGPreflightListenEventAccess()`, request with `CGRequestListenEventAccess()` | Works in a sandbox since 10.15 |
| `NSEvent.addGlobalMonitorForEvents` for key events | Accessibility | Observe only, not called for the app's own events |
| Posting `CGEvent` key events (the synthetic Cmd+V) | Accessibility, or the PostEvent grant. `CGPreflightPostEventAccess()`, `CGRequestPostEventAccess()` | |
| `AXUIElement` reads and writes | Accessibility (`AXIsProcessTrusted`) | |
| `AVAudioEngine` capture | Microphone | |

Rules for Fn:

- Fn arrives as a `flagsChanged` event with key code 63 (`kVK_Function`) and `CGEventFlags.maskSecondaryFn`. The same flag is also set on arrow, navigation, and F-key events, so Fn state must come only from `flagsChanged` events with key code 63.
- Watch `keyDown` during a bare-Fn hold. If another key is pressed, Fn is being used as a chord modifier and the recording must be cancelled.
- Guard modifier-only hotkeys so that releasing an unrelated modifier does not re-arm the press.
- The Apple Fn key fires only from Apple keyboards. Third-party keyboards handle Fn in firmware and send nothing. Always offer a fallback binding (Ctrl+Opt).
- The macOS "Press Globe key to" setting still fires on an Fn tap (emoji picker, input source switch, or Apple Dictation on double press). A listen-only tap cannot suppress it, and no documented API can. Onboarding must tell the user to set it to Do Nothing (medium).
- Taps are disabled by timeout. Handle `tapDisabledByTimeout` and `tapDisabledByUserInput`, and poll `CGEvent.tapIsEnabled` and `CGPreflightListenEventAccess` on a short interval. There is no callback when permission is revoked.
- TCC grants are bound to code identity. An ad-hoc or re-signed development build can produce a tap that is created and enabled but never fires. Use a stable signing identity for local development (medium).

### Why the tap is listen-only

An open, Apple-acknowledged bug (FB24619068, forum thread from about September 2026, medium) affects active session-level taps: if the user revokes the app's Accessibility permission while a `.defaultTap` is installed, all system input becomes unresponsive and a forced restart is needed. It is reported on macOS Sequoia, Tahoe, and the macOS 27 beta. A push-to-talk app never needs to swallow events, Wispr's own docs say keyboard shortcuts are never suppressed, and the stuck-modifier incident in section 5 shows what an active filter can do to other apps. Hush therefore uses `.listenOnly`, accepts that the hotkey also reaches the frontmost app, and picks defaults (Fn, Ctrl+Opt) that are harmless when they do.

### AX insertion fails silently, so paste is the workhorse

- The AX approach: get the system-wide focused element, check that `kAXSelectedTextAttribute` is settable, set it to the transcript. This replaces the selection or inserts at the caret.
- Measured failure (medium, from another project's pull request): in a Chrome textarea the attribute reports settable, the set returns success, and the value is unchanged two seconds later. The same silent drop affects Chrome, Slack, VS Code, and other browser or Electron editors. Cmd+V landed in 37 ms in the same test. Terminals and custom-drawn editors also implement AX writes only partially.
- Consequence for `InsertionStrategySelector`: never trust a success return. Either read the value back to verify, or route Chromium, Electron, and web views straight to paste by bundle id. v0.1 ships paste insertion. The AX path is added only with read-back verification.

Paste fallback details that Hush's `PasteInserter` must cover:

1. Snapshot every pasteboard item as type and data pairs. Tolerate a nil read without crashing.
2. Write the transcript as `.string`, plus empty data for `org.nspasteboard.TransientType` and `org.nspasteboard.AutoGeneratedType` so clipboard managers skip it. Wispr marks its text concealed for the same reason.
3. Confirm the write landed (`changeCount`) before posting keys.
4. Resolve the key code for "v" against the current keyboard layout with `TISCopyCurrentKeyboardInputSource` and `UCKeyTranslate`. A hardcoded key code 9 breaks Dvorak, Colemak, and Neo2.
5. Post Command down, V down, V up, Command up with `.maskCommand`, with small gaps (about 10 ms).
6. Restore the snapshot after a delay in the 250 ms to 1 s range, and only if the pasteboard still holds the transcript. A `changeCount`-only guard is not enough, because Universal Clipboard and browsers bump it in the background.
7. If the paste cannot be attempted (no Accessibility grant, no focused field), leave the transcript on the clipboard, do not restore, and tell the user. This matches Wispr's documented failure behavior.
8. After a macOS update a stale Accessibility grant can report trusted while silently dropping the synthetic Cmd+V. The tap health check doubles as a signal for this.
9. Known environments where paste does not land: secure fields, remote desktop and VDI clients, WSL and SSH sessions, and Flutter macOS apps that drop the Command modifier on injected events. These belong in docs/MANUAL_TEST.md and the user-facing troubleshooting notes.

### Pasteboard privacy

macOS 15.4 introduced a pasteboard privacy preview (medium). Programmatic reads of the general pasteboard that are not tied to a user paste trigger an alert, and there is a per-app "Paste from Other Apps" setting. Through macOS 26 it is opt-in with `defaults write <bundle id> EnablePasteboardPrivacyDeveloperPreview -bool yes`. The clipboard snapshot in step 1 above is exactly the kind of read it flags. Clipboard restore must therefore be optional, and the manual test plan should include a run with the flag enabled for `io.github.ryan-stoffel.hush`.

### SMAppService

`SMAppService.mainApp.register()` and `unregister()` (macOS 13+) manage launch at login with no helper bundle. The status values are `.notRegistered`, `.enabled`, `.requiresApproval`, and `.notFound`. The settings toggle must read `status` live instead of persisting its own flag, because the user can disable the item in System Settings. `SMAppService.openSystemSettingsLoginItems()` opens the right pane. Planned for v1.0.

### Non-activating panel configuration

For the overlay (`OverlayPanelController`, v0.1):

- Pass `.nonactivatingPanel` in the `NSPanel` initializer (together with `.fullSizeContentView`). Setting it in the initializer is best practice. The claim that setting it later fails is unverified.
- Override `canBecomeKey` and `canBecomeMain` to return false.
- Show it with `orderFrontRegardless()`. Never call `makeKeyAndOrderFront` or `NSApp.activate`.
- `isFloatingPanel = true`, `level = .floating`, `hidesOnDeactivate = false`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, clear background, not opaque, no shadow.
- `ignoresMouseEvents = true`, because the overlay is display only.

### XCUITest with agent apps

- XCUITest cannot run from pure SwiftPM. It needs an Xcode project with an application target and a `bundle.ui-testing` target. Hush keeps all logic in the Swift package and generates a thin project with XcodeGen (`project.yml`), which is why `Hush.xcodeproj` is never committed.
- Status item clicks in LSUIElement apps are flaky (medium). The app never becomes frontmost, so when the current space is full screen the menu bar is hidden and the element is reported as not hittable. On macOS 26 third-party status items may also be rehosted by Control Center.
- Mitigation: the skeleton already parses `-demoMode YES -demoScene <name>` (`DemoMode` in HushCore) and the UI test harness passes those arguments. Opening the named scene directly is planned (`DemoScene`, arriving with the first window), so that the screenshot suite in `UITests/` never has to click the status item.
- The GitHub runner image grants Accessibility, PostEvent, Microphone, and ScreenCapture only to bash and the runner provisioner, with no Input Monitoring entries. The app under test has none of these permissions on CI. Demo mode therefore never touches the microphone, event taps, Accessibility, the Keychain, or the network. Real dictation is verified by hand with docs/MANUAL_TEST.md.

### GitHub runner images

- `macos-latest` and `macos-26` are macOS 26 on arm64 with Xcode 26.6 as the default. `macos-15` defaults to Xcode 16.4. `macos-14` is deprecated and becomes unsupported on 2026-11-02.
- Images are built with autologin and automation mode enabled without authentication, which removed the historical automation-mode timeouts in UI tests.
- Hush's CI uses `macos-26` runners with Xcode 26. Local builds need Xcode 16 or newer.
- Whether Core ML or Neural Engine inference works inside GitHub's macOS VMs is unverified. CI must not depend on real WhisperKit inference.

## 8. Deliberate differences from Wispr Flow

| Area | Wispr Flow | Hush |
| --- | --- | --- |
| Where speech is processed | Cloud only, internet required for every dictation | On-device by default with WhisperKit. Cloud backends are optional and arrive in v0.3 |
| Source and license | Proprietary | Open source, MIT |
| Account | Mandatory sign-in | No account. No sign-in step anywhere |
| Pricing and limits | Weekly word cap on the free tier, subscription for unlimited use and Command Mode | No caps, no tiers, no plan gates |
| Team features | Shared dictionary and snippets, usage dashboards, leaderboard, admin controls, SSO | None planned |
| Notetaker | Meeting capture, summaries, cross-meeting Q and A, MCP connector | None planned. Hush does dictation only |
| Mobile and other platforms | iPhone, Android, Windows | macOS 14+ only |
| Context sent with each dictation | App, surrounding text, on-screen text, screenshot (on by default) | Nothing is sent. No screenshots, no tree traversal, no URL reads |
| Telemetry | Multiple analytics and error services (medium) | None |
| Key handling | Reported as an active tap that filters keystrokes (medium) | Listen-only tap |
| Audio retention | Audio kept locally for 14 days for retry and playback | Audio is never written to disk |
| Sync | Dictionary, snippets, and notes sync through the cloud | Local JSON files with import and export |
| Overlay | Optional always-on pill | Overlay only during a session |
| Launch at login | On by default | Off by default |
| Cleanup default | Light AI cleanup by a hosted LLM | Deterministic rules. The LLM stage is optional |
| Intel Macs | Supported (dedicated build) | Builds universal, but local transcription is unavailable on Intel. A cloud backend is required there |

Features we chose not to match: Styles with URL detection, dictionary auto-learn by watching text fields, Scratchpad, Transforms, Insights and streaks, web-search voice commands, mouse button bindings, IDE file tagging and variable recognition. Some may be revisited after v1.0 through an issue. None will be added in a form that breaks the commitments in section 5.

## 9. Could not verify

Merged from all six research passes.

### Wispr Flow product and docs

- Auto Cleanup: exact per-level behavior and whether the High level is available to all users. The dedicated help article is marked as not currently available. A screenshot shows four levels, and the navigation article lists three.
- Desktop session length: several current help articles still say about 6 minutes. Four articles and the March 2026 changelog say 20 minutes with a 19-minute warning. One article labels 20 minutes as Mac only. We treat 20 minutes as current on Mac and could not confirm Windows.
- Mobile session limits: help articles conflict (5 minutes versus no maximum on Android, and an iOS limit stated in only one article).
- Dictionary entry length limit: 60 characters in three articles, 30 in two others (with at most 200 words synced at a time).
- Free desktop word cap: 2,000 per week on the pricing page, 1,000 per week in one help article.
- Defaults for paste last and copy last transcript: most articles give Cmd+Ctrl+V and Cmd+Ctrl+C. Three articles say one or both have no default. This may vary by build.
- Behavior after a failed paste: most articles say the dictated text stays on the clipboard. One says some builds restore the previous contents, and one warns the text may be gone.
- Where pasted text lands: one article says the app tracks the field focused at the start, another says it pastes into whatever is focused when transcription finishes.
- Whether desktop history supports per-transcript delete (articles conflict).
- Whether the pill's right-click menu offers language switching and "Hide for 1 hour" (four articles list different item sets).
- Exact name and location of the pill visibility setting (three different paths in the docs).
- Current location of the auto-add to dictionary toggle (Personalization according to one page, System > Extras according to a screenshot).
- Timing thresholds are not documented anywhere: the double-tap window, the minimum hold duration, the clipboard restore delay, and how much leading audio is discarded.
- Whether any in-app whisper mode setting exists. Only hardware guidance and a marketing blurb were found.
- The Sound Effects toggle's exact UI label, and the sound design itself (pitch, duration, distinct start and stop sounds, error sounds).
- Real on-screen size of the pill in idle, hover, and recording states. Only marketing SVG dimensions and a third-party estimate exist.
- How Command Mode is shown visually, and what the processing state looks like.
- Whether the finish control on the Mac pill is a stop square or a checkmark.
- Placement and styling of desktop notifications. No screenshots of the Home page or onboarding screens were obtained.
- Multi-monitor behavior of the pill.
- Labels of three icons in the collapsed Hub sidebar.
- Notetaker weekly meeting limits for Free and Pro.
- SOC 2 Type II and ISO 27001 status: marketing pages and the security FAQ conflict, two compliance articles returned 404, and the trust center was not fetched.
- Names of third-party ASR and LLM subprocessors (not publicly disclosed; the list used above is competitor-compiled).
- Production status of the Canto model.
- Installer variants and build numbers (download pages render as sign-in pages). No changelog entries before 2026-03-31 are visible.
- Several help articles returned no usable content (chaining actions, Fetch Links, routing dictation to Slack or email) and five were not read in full (retry failed transcriptions, "Taking longer than usual", system requirements, Privacy Mode and Cloud Sync, Mouse Flow setup).
- Most changelog entries from late May 2026 onward come from a model summary of the page. Only the Mar 31, May 1, Aug 21, Sep 4, and Sep 15 entries were spot-checked against raw page text.

### Reviews and incidents

- Reddit threads could not be opened. Titles, vote counts, and quotes come only from search snippets.
- The Digital Trends original of the feedback-thread story returned empty content (a Yahoo syndication was used), and the CEO's post on X was not fetched.
- The NYT Magazine article and the Wirecutter guide are blocked. Wirecutter's methodology and its listed flaws are unverified.
- The Business Insider hot-mic article is blocked, so which mode caused the accidental dictation is not confirmed.
- Two Medium posts and the Podfeet review returned 403. efficient.app returned 429. Pill hover details attributed to Podfeet come from a search snippet.
- The 800 MB, 8% CPU, and 8 to 10 s startup figures have no independent measurement and appear to describe the Windows app.
- The 97.2% accuracy figure has no traceable primary source.
- The How-To Geek review cited by Wikipedia was not located.
- No reviewer-documented case of the pill stealing focus was found.
- The April 2026 forensic findings were read only in the author's own write-up. No response from Wispr was found, and later remediation is competitor-reported.
- YouTube reviews and walkthroughs were not transcribed. web.archive.org could not be fetched.

### Open-source projects

- Star, fork, and issue counts are rounded page values, not exact.
- The handy-keys repository URL returned 404. Its Fn handling and whether it uses an event tap on macOS are undocumented.
- Handy's default macOS transcription hotkey.
- VoiceInk's exact Fn detection code, its latest release, and its current price.
- Whether OpenWhispr still uses an AppleScript paste path, and its clipboard restore timing.
- The legacy Hex default hotkey, whether its key monitor is an event tap, and the internals of the Rust rewrite.
- Whispering's default macOS shortcut, latest version, and concrete paste implementation.
- Amical's Fn detection, insertion, and default hotkey.
- TypeWhisper and OpenSuperWhisper insertion code and default hotkeys.
- FluidVoice's default hotkey and the exact ordering of its insertion tiers in the current release.
- Spokenly internals (closed source).
- Release versions and dates for most projects.
- Completeness of the taken-names list. Only the top 20 to 60 repos per GitHub topic were read, and the App Store, Homebrew, and trademark registries were not searched.

### Platform and tooling

- Whether a listen-only tap restricted to `flagsChanged` still requires Input Monitoring on macOS 14, 15, and 26. Not tested. Hush requests Input Monitoring anyway.
- Whether `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` delivers Fn changes without Accessibility on current macOS.
- The default value of "Press Globe key to" on current Macs. The "set it to Do Nothing" advice comes from a third-party snippet, not a fetched help page.
- Any way for a third-party app to suppress the system Fn or Globe action. None was found, and how Wispr handles it internally is undocumented.
- XCUITest status item guidance rests on one Apple forum thread plus the API reference. Stack Overflow, Reddit, and two Medium articles could not be fetched.
- No primary source documents status-item click flakiness specifically on GitHub-hosted runners.
- Whether Core ML or Neural Engine backed WhisperKit inference works inside GitHub's macOS arm64 VMs.
- Whether WhisperKit v1.1.0 compiles for x86_64.
- Pasteboard privacy enforcement status in macOS 27. It was verified as opt-in only through macOS 26.
- The claim that changing `styleMask` to `.nonactivatingPanel` after init does not take effect.
- Sparkle's `generate_appcast` flags were taken from the 2.10.0 source, not from the documentation pages.

## 10. Naming

Renamed on 2026-09-20: the project shipped its first pre-release as Quoth and is now called Hush. The checks below were made for the earlier name; "hush" was chosen by the maintainer knowing that a Safari nag blocker called Hush exists (oblador.github.io/hush, also a Homebrew cask named `hush`), so the bundle id `io.github.ryan-stoffel.hush` and the fully qualified cask name `ryan-stoffel/taps/hush` keep them apart.


Chosen name: Hush, an archaic English word for "said". Repository `ryan-stoffel/hush`, bundle id `io.github.ryan-stoffel.hush`.

Constraints: short, original, not built on another product's trademark (no wispr, whisper, or flow stems), and not an existing popular GitHub repository or Mac app.

Checks run on 2026-09-17:

- GitHub repository search for `hush in:name`, sorted by stars: 88 results. The largest is erykwalder/hush with 51 stars, a Go quoting library. Nothing in the dictation space.
- Web search for "Hush" with macOS, Mac App Store, and dictation: no Mac app found. The only product found is a 2011 word puzzle game on the Amazon Appstore for Android.
- `ryan-stoffel/hush` did not exist.
- App Store, Homebrew, and trademark registries were not searched.

Rejected candidates (top GitHub hit in parentheses):

| Candidate | Reason |
| --- | --- |
| Sotto | At least seven existing macOS dictation apps and repos use this exact name |
| Chirrup | Too close to Chirp, an existing native Mac dictation app |
| Natter | MikeWang000000/Natter (2,210 stars) |
| Hark | 2ship2harkinian (2,234), otalk/hark (571) |
| Verba | weaviate/Verba (7,706) |
| Lilt | A translation company. Also lilToon (1,564) |
| Blurt | mozilla/blurts-server (942). Blurt is also a writing app |
| Parlo, Parlor | fikrikarim/parlor (2,067) |
| Voxel, Murmur, Quill, Utter, Mutter, Jabber, Yammer | Well-known existing products |
| Prattle, Blether, Parlando, Chunter | Clear on GitHub (largest repos 21, 1, 4, and 44 stars) but weaker names. Kept as fallbacks |

Names already used by dictation tools and therefore avoided: Superwhisper, MacWhisper, VoiceInk, Aqua Voice, Willow, Monologue, Talon, Spokenly, Handy, Hex, FluidVoice, OpenWhispr, Whispering, OpenLess, Ghost Pepper, OpenSuperWhisper, FreeFlow, TypeWhisper, Amical, Muesli, Voicy, Voibe, Chirp, Keet, Mumble. The open-source survey found roughly 150 taken names in this space. The heavily reused stems to avoid are Whisper and its variants, Flow, Voice, Vox, Voca, Type, Dict, Yap, Say, Speak, Murmur, Parrot, Parakeet, Ink, and Quill.

## 11. Sources

Deduplicated list of every source URL cited in the research data, grouped by kind. All were fetched on 2026-09-17 unless section 9 says otherwise.

### Official site (wisprflow.ai)

- <https://wisprflow.ai/>
- <https://wisprflow.ai/features>
- <https://wisprflow.ai/whats-new>
- <https://wisprflow.ai/pricing>
- <https://wisprflow.ai/privacy>
- <https://wisprflow.ai/notetaker>
- <https://wisprflow.ai/post/series-b>
- <https://wisprflow.ai/post/flow-on-android>
- <https://wisprflow.ai/blog>
- <https://wisprflow.ai/post/technical-challenges>
- <https://wisprflow.ai/data-controls>

### Official help center (docs.wisprflow.ai)

- <https://docs.wisprflow.ai/articles/2612050838-supported-unsupported-keyboard-hotkey-shortcuts>
- <https://docs.wisprflow.ai/articles/6391241694-use-flow-hands-free>
- <https://docs.wisprflow.ai/articles/4841123325-longer-dictation-sessions-now-up-to-20-minutes>
- <https://docs.wisprflow.ai/articles/4816967992-how-to-use-command-mode>
- <https://docs.wisprflow.ai/articles/8068950331-how-to-use-transforms-beta>
- <https://docs.wisprflow.ai/articles/5373093536-how-do-i-use-smart-formatting-and-backtrack>
- <https://docs.wisprflow.ai/articles/2368263928-how-to-setup-flow-styles>
- <https://docs.wisprflow.ai/articles/5784437944-create-and-use-snippets>
- <https://docs.wisprflow.ai/articles/4052411709-teach-flow-your-words-with-the-dictionary>
- <https://docs.wisprflow.ai/articles/3191899797-use-flow-with-multiple-languages>
- <https://docs.wisprflow.ai/articles/4678293671-feature-context-awareness>
- <https://docs.wisprflow.ai/articles/5096240724-navigating-the-wispr-flow-app-desktop-ios-and-android>
- <https://docs.wisprflow.ai/articles/9618237082-using-the-scratchpad-to-save-and-edit-notes>
- <https://docs.wisprflow.ai/articles/6434410694-use-flow-with-cursor-vs-code-and-other-ides>
- <https://docs.wisprflow.ai/articles/1036674442-supported-devices-and-system-requirements>
- <https://docs.wisprflow.ai/articles/4760791189-free-tier-weekly-word-cap-and-bonus-words-remove-desktop-trial-experiment>
- <https://docs.wisprflow.ai/articles/4709791908-understanding-privacy-mode-and-cloud-sync>
- <https://docs.wisprflow.ai/articles/3467817258-security-and-compliance-faq>
- <https://docs.wisprflow.ai/articles/4218718535-hipaa-compliance-healthcare-use>
- <https://docs.wisprflow.ai/articles/9192039587-using-wispr-flow-discreetly-microphone-guide>
- <https://docs.wisprflow.ai/articles/7971211038-fix-text-not-pasting-after-dictation>
- <https://docs.wisprflow.ai/articles/6409258247-starting-your-first-dictation>
- <https://docs.wisprflow.ai/articles/4283510616-auto-cleanup-control-how-much-flow-edits-your-dictation-beta>
- <https://docs.wisprflow.ai/articles/3405181237-ranked-microphone-preferences-and-automatic-mic-switching>
- <https://docs.wisprflow.ai/articles/7231650589-auto-mute-music-while-dictating-on-macos-how-audio-detection-works>
- <https://docs.wisprflow.ai/articles/1790396454-move-and-dock-the-flow-bar-on-desktop>
- <https://docs.wisprflow.ai/articles/4048537120-what-to-expect-from-flow-accuracy-and-known-limitations>
- <https://docs.wisprflow.ai/articles/5510622673-re-verify-wispr-flow-permissions-after-updating>
- <https://docs.wisprflow.ai/articles/8841649969-fix-flow-shortcuts-blocked-by-macos-secure-keyboard-entry-secure-event-input>
- <https://docs.wisprflow.ai/articles/3941699399-keyboard-and-screen-reader-accessibility-in-wispr-flow>
- <https://docs.wisprflow.ai/articles/3155947051-troubleshooting-guide-for-no-model-available-error>
- <https://docs.wisprflow.ai/articles/8760230576-your-usage-tab-track-your-dictation-stats-in-wispr-flow>
- <https://docs.wisprflow.ai/articles/3152211871-setup-guide>

### Official screenshots and assets

- <https://cdn.prod.website-files.com/682f84b3838c89f8ff7667db/6a4f5ff3f6da81ba30f2416b_Flowbar.svg>
- <https://cdn.prod.website-files.com/682fa12727f78b943ed45584/6a5546256f3274b2b7716a4b_CleanShot%202026-07-13%20at%2013.09.32.png>
- <https://cdn.prod.website-files.com/682fa12727f78b943ed45584/6a3dcd84ea71520f895c1ad6_CleanShot%202026-06-25%20at%2017.00.58%402x.png>
- <https://cdn.prod.website-files.com/682fa12727f78b943ed45584/69cd48504a0c73eedc44a18f_Screenshot%202026-04-01%20at%209.30.47%E2%80%AFAM.png>

### Independent reviews, press, and community

- <https://voice-list.com/compare/aqua-voice-vs-wispr-flow/>
- <https://zackproser.com/blog/wisprflow-review>
- <https://www.technovice.net/post/wispr-flow-review>
- <https://www.producthunt.com/products/wisprflow/reviews>
- <https://wensenwu.com/thoughts/wispr-flow-investigation>
- <https://www.getvoibe.com/resources/is-wispr-flow-safe/>
- <https://tech.yahoo.com/apps/articles/wispr-flow-finally-fixed-toolbar-103632302.html>
- <https://spokenly.app/blog/wispr-flow-review>
- <https://tldv.io/blog/wisprflow/>
- <https://techcrunch.com/2026/05/02/the-best-ai-powered-dictation-apps-of-2025/>
- <https://zapier.com/blog/wispr-flow/>
- <https://news.ycombinator.com/item?id=47040375>
- <https://www.digitalapplied.com/blog/open-source-voice-dictation-tools-wispr-alternatives>
- <https://willowvoice.com/blog/wispr-flow-review-voice-dictation>
- <https://i0exception.substack.com/p/wispr-flow-vs-death-metal>
- <https://finance.yahoo.com/technology/ai/articles/wispr-raises-280m-2b-valuation-131005441.html>
- <https://adamjones.me/blog/best-dictation-apps-2026/>
- <https://www.growthdives.com/p/how-wispr-nails-onboarding>

### Open-source projects

- <https://github.com/Beingpax/VoiceInk>
- <https://raw.githubusercontent.com/Beingpax/VoiceInk/main/VoiceInk/Infrastructure/SystemIntegration/Paste/CursorPaster.swift>
- <https://tryvoiceink.com/docs/shortcuts>
- <https://github.com/beingpax/voiceink/issues/610>
- <https://github.com/cjpais/Handy>
- <https://github.com/cjpais/handy/issues/2036>
- <https://github.com/cjpais/Handy/issues/1925>
- <https://github.com/altic-dev/FluidVoice>
- <https://raw.githubusercontent.com/altic-dev/FluidVoice/main/Sources/Fluid/Services/TypingService.swift>
- <https://github.com/altic-dev/FluidVoice/issues/657>
- <https://github.com/OpenWhispr/openwhispr>
- <https://raw.githubusercontent.com/OpenWhispr/openwhispr/main/resources/macos-globe-listener.swift>
- <https://raw.githubusercontent.com/OpenWhispr/openwhispr/main/resources/macos-fast-paste.swift>
- <https://github.com/zachlatta/freeflow>
- <https://github.com/zachlatta/freeflow/issues/105>
- <https://raw.githubusercontent.com/zachlatta/freeflow/main/Sources/AppState.swift>
- <https://raw.githubusercontent.com/kitlangton/Hex/main/CLAUDE.md>
- <https://raw.githubusercontent.com/kitlangton/Hex/main/Hex/Clients/PasteboardClient.swift>
- <https://github.com/epicenterhq/epicenter/blob/main/docs/adr/0117-global-shortcut-input-is-plugin-chords-only-and-the-macos-tap-is-just-the-paste-grant-watcher.md>
- <https://raw.githubusercontent.com/Starmel/OpenSuperWhisper/master/OpenSuperWhisper/ModifierKeyMonitor.swift>
- <https://github.com/TypeWhisper/typewhisper-mac>
- <https://spokenly.app/open-source>
- <https://github.com/topics/dictation?o=desc&s=stars>
- <https://github.com/openwhispr/openwhispr/issues/826>
- <https://github.com/primaprashant/awesome-voice-typing>
- <https://raw.githubusercontent.com/Beingpax/VoiceInk/main/VoiceInk/Features/Recording/Presentation/MiniRecorderPanel.swift>
- <https://github.com/OrangeAKA/pillfloat>

### Primary technical sources

- <https://github.com/flutter/flutter/issues/184571>
- <https://github.com/argmaxinc/argmax-oss-swift/releases>
- <https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/v1.1.0/Package.swift>
- <https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/v1.1.0/Sources/WhisperKit/Core/WhisperKit.swift>
- <https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/v1.1.0/Sources/WhisperKit/Core/Configurations.swift>
- <https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/v1.1.0/Sources/ArgmaxCLI/TranscribeCLI.swift>
- <https://github.com/argmaxinc/argmax-oss-swift/issues/92>
- <https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0>
- <https://sparkle-project.org/documentation/programmatic-setup/>
- <https://sparkle-project.org/documentation/sandboxing/>
- <https://origin-devforums.apple.com/forums/thread/707680>
- <https://developer.apple.com/forums/thread/844416>
- <https://github.com/basedhardware/omi/issues/13232>
- <https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/>
- <https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp>
- <https://developer.apple.com/forums/thread/773715>
- <https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md>
- <https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md>
