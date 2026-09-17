<!--
Title format: type(scope): summary
Types: feat, fix, chore, docs, refactor, test, ci, build, perf
Scopes: audio, hotkey, transcription, cleanup, insertion, ui, settings, ci, release, docs, deps
Branch format: feature|bug|chore|docs/gh-issue-<number>-<slug>, branched from develop.
-->

Closes #

## Summary

<!-- What changed and why, in a few sentences. -->

## Before and After

<!--
CI builds the merge base and this branch, captures every window, and writes the table between the two
markers below. Leave the markers exactly as they are. If this pull request changes no UI, replace this
comment with the three words: No UI change
-->

<!-- screenshots:start -->
<!-- screenshots:end -->

## Testing

<!-- Commands you ran and what you checked by hand. -->

- [ ] `scripts/lint.sh`
- [ ] `scripts/test.sh unit`
- [ ] `scripts/test.sh ui`
- [ ] docs/MANUAL_TEST.md sections for the areas this touches (audio, hotkey, transcription, insertion), or not applicable

## Checklist

- [ ] The branch name matches `feature|bug|chore|docs/gh-issue-<number>-<slug>`
- [ ] The title is `type(scope): summary`
- [ ] This pull request links exactly one issue with `Closes #<number>` or `Fixes #<number>`
- [ ] New windows or tabs have a demo scene and a screenshot test
- [ ] No new dependency, or it is approved in the linked issue and justified in Package.swift
- [ ] Nothing leaves the machine unless the user picked a cloud backend
- [ ] CHANGELOG.md is updated under Unreleased for user-visible changes
- [ ] AGENTS.md and CLAUDE.md are still in sync if either changed
