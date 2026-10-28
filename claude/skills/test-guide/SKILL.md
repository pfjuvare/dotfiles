---
name: test-guide
description: Generate an annotated, screen-by-screen HTML test guide for a WebEOC test flow (view rendered offline from board source, with highlights, arrows and numbered callouts) and link it in the conversation. Dev guide by default; `--uat` for a plain-English pass/fail version for UAT testers. Use whenever you give PJF a testing flow for a WebEOC change (delegate stream test gate or repro flow, orchestrator relay, ad-hoc "give me a test flow"), or when he types /test-guide.
argument-hint: '[--uat] [<stream / topic>]'
---

# /test-guide

The guide **complements** the text test flow: still write the concise text flow (it goes to the
orchestrator and the MR), then generate the guide from it and link it. Tool: `~/code/webeoc-guide`
(README there has the full flow-file format; `examples/agvic-branch-input.yaml` is a worked example).

## Steps

1. **Flow file**: write `<name>-guide.yaml` at the worktree / repo root (`<name>` = stream name, or a short
   topic slug outside a stream). Make sure `/*-guide.*` is in `$(git rev-parse --git-common-dir)/info/exclude`
   (new streams get it from `spawn-stream.sh`). `boardDir` is relative to the flow file, e.g. `boards/agvic-ops`.
2. **Dev text = the text flow.** One step per flow step, the same terse wording: `instruction` is the action,
   `expect` the result, and callout `label`s are 1–3 words. `dev:` holds the implementation pointer (function,
   selector, what to check in data). Put `setup:` (position, incident, where to start) at the top.
3. **UAT only with `--uat`** (never by default): add `uat:` overrides (title, intro, setup, scene name, and
   per-step instruction / expect / callout text) in plain English with no code terms or field names, then render with `--uat`.
4. **Fixtures from code, not guesses.** The board's JS doesn't run in the preview. Read the view's board JS
   and fake what it would do (select options, hint text, locked or disabled states, toggled sections) with
   `fixtures` / `set`. MDB selects need `mdbSelect: true`. Use sample data, never real records. If a
   behaviour can't be read from code, leave it out of the visuals and keep it in the text only.
5. **Render**: `node ~/code/webeoc-guide/bin/webeoc-guide.js render <name>-guide.yaml [--uat]`. A selector
   that matches nothing fails the run: fix the flow, or the view if the flow caught a real gap. The first
   time you render a view, add `--debug <scratch dir>` and look at the PNG to check the render looks right.
6. **Reply**: after the text flow, add one line saying what the guide covers, then the `link` URL the CLI
   printed on its own line:
   ```
   Guide (Add/Edit Branch: EM Coordinator inheritance, default lock):
   file://wsl.localhost/Ubuntu/home/…/uat-3sJx4mjm-guide.html
   ```
   Windows Terminal ctrl+click opens it in the Windows browser. If PJF asks you to open it, re-run with `--open`.

## In /delegate streams

- **Test gate** (and the repro flow, for defects): generate the guide and put its link in the same message
  as the text flow, both to PJF and in the `SendMessage` to the orchestrator.
- **Orchestrator**: relay the stream's guide link along with its test flow. For the post-merge live re-test,
  reuse the stream's guide (re-render it if the flow changed).

## Skip it (one line saying why) when

- the flow isn't visual: list/group pushes, REST data scripts, server-side expressions only.
- the screen is built almost entirely by board JS from REST data (most list / details views), so it would
  need fixtures for nearly everything. A guide is still worth it if the changed controls are static markup.

## Safety

The renderer never contacts WebEOC. `*.webeocasp.com` is refused even if allowlisted, because Imperva
rate-blocks tooling. Don't add WebEOC hosts to `allowHosts`. Guides use sample data only, so they're safe to
attach to an MR or send to a tester.
