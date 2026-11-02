---
name: test-guide
description: Generate an annotated, screen-by-screen HTML test guide for a WebEOC test flow (view rendered offline through the platform's own view.xsl pipeline with the board's JS running, with highlights, arrows and numbered callouts) and link it in the conversation. Dev guide by default, built on real dev records (`--sample` for made-up data); `--uat` for a plain-English pass/fail version for UAT testers, on sample data. Use whenever you give PJF a testing flow for a WebEOC change (delegate stream test gate or repro flow, orchestrator relay, ad-hoc "give me a test flow"), or when he types /test-guide.
argument-hint: '[--uat] [--sample] [<stream / topic>]'
---

# /test-guide

The guide **complements** the text test flow: still write the concise text flow (it goes to the
orchestrator and the MR), then generate the guide from it and link it. Tool: `~/code/webeoc-guide`
(README there has the full flow-file format; `examples/agvic-branch-input.yaml` is a worked example).

## Scope: test what changed, nothing more

The flow (text and guide alike) covers only what this stream changed, so PJF spends testing time where the
risk is:

- **One step per change you made**, or per behaviour the change affects. Don't add general re-checks of
  things the change didn't touch, "while you're there" checks, or a full regression pass, unless an issue
  was reported or you found one there.
- **QA tickets and defect lists:** target each reported defect. The flow is organised by defect (in the
  ticket's numbering), each step confirming that defect is fixed. One defect can need several steps if
  several pieces of behaviour changed for it; defects closed with no change (by design, not reproducible)
  get no step, just one line saying why.
- **A side effect you know of** (you changed shared code, a list, a permission) earns one step for it. Name
  it as the side effect so PJF knows why it's there.
- If you think a wider re-test is genuinely needed, say so in one line and let PJF decide; don't build it in.

## Data: real dev records (dev guide), sample data (`--sample`, `--uat`)

| Guide | Default data | Option |
|---|---|---|
| dev (no flag) | **real DEV records**: the screens show what PJF will see on dev | `--sample`: made-up data |
| `--uat` | **sample data**: made-up names and values, safe to send to testers | none |

- **Real records** (dev default): read the records the flow touches from **DEV** via REST, read-only,
  and put them in the flow's `data:` / `api:`: real names, positions, statuses and counts. Set
  `dataSource: dev` and `dataAsOf: <when read>` at the top so the header says so. Expected
  results then match dev exactly. Read only what the screens need. DEV only, never Demo/Test/Prod.
  Hosted hosts (`*.webeocasp.com`) sit behind Imperva: one login, a handful of reads, no retries, and on
  an Incapsula 403 stop all requests and report the incident ID to PJF.
- **Sample data** (`--sample`, and always with `--uat`): made-up names and values, never real records.
  Use it when the flow doesn't depend on dev's state, or the guide goes outside the team.
- A dev guide on real records holds client data: keep it local and internal (stream folder, MR for
  the team). Send testers the `--uat` guide.

## Test data on dev: set it up, don't leave it to be found

When a flow needs dev records in a state dev doesn't have (e.g. a role assignment in Withdrawal
Supported or Accepted (Pending)), sort the setup out while making the guide. Don't leave it as
prerequisites for PJF to discover.

- Set the records up on **DEV** as part of making the guide (`webeoc-rest-script` skill, a narrow write
  view, dry run first). **Confirm with PJF before the first data write.** Never on Demo/Test.
- With no safe write path (no narrow REST view for the field, or the change must go through the UI's
  workflow), make it an explicit numbered **Setup (do first)** list at the very top: in the flow's
  `setup:` and as the first lines of the text flow. Give the person, the record and old → new value.
  Never bury setup in a scene description or a step's context.
- The guide's header says what was set up or changed on dev, so expected counts and states match
  what PJF will see. Expected numbers come from dev's state after that setup, not from a guess.

## Steps

1. **Flow file**: write `<name>-guide.yaml` at the worktree / repo root (`<name>` = stream name, or a short
   topic slug outside a stream). Make sure `/*-guide.*` is in `$(git rev-parse --git-common-dir)/info/exclude`
   (new streams get it from `spawn-stream.sh`). `boardDir` is relative to the flow file, e.g. `boards/agvic-ops`.
   If the work is for a Trello card or Jira issue, set `ticket: <shortLink | KEY>` at the top: the guide then
   embeds the ticket (description, checklists, comments) as an expanded panel, fetched via `ptc` / `pjc` at
   render time.
2. **Dev text = the text flow.** One step per flow step, the same terse wording: `instruction` is the action,
   `expect` the result, and callout `label`s are 1–3 words. `dev:` holds the implementation pointer (function,
   selector, what to check in data). Put `setup:` (position, incident, where to start) at the top.
   **Context first:** every step that changes behaviour gets a very concise `context:` (one or two lines)
   saying what it was like before the change: the defect or the old state. `expect` then reads as the new
   behaviour. Context shared by several steps goes once at scene level (`context:` on the scene). Don't repeat
   what the scene or an earlier step already said. Pure setup or navigation steps get none. Take it from the
   card, the ticket or the diff, never from a guess; if the before-state isn't known, leave it out.
3. **UAT only with `--uat`** (never by default): add `uat:` overrides (title, intro, setup, scene name and
   context, and per-step context / instruction / expect / callout text) in plain English with no code terms or field names, then render with `--uat`.
   Its data is sample data (see "Data"). If the dev guide uses real records, write the UAT guide from its own
   flow file, `<name>-uat-guide.yaml`, a copy with the `data:` / `api:` swapped for made-up records, so no
   real record reaches a tester.
4. **Data and mocks, not fixtures.** The view is compiled by the platform's own `view.xsl` (from
   `~/code/webeoc-src`) and the board's JS runs, so feed it what it reads:
   - `data:` builds the `/data` document. Use `record` for a details/input view, `records` for a list
     view (a list without them renders empty), `attrs: { dataid: 0 }` + `records: []` for an Add form,
     `params` for ViewParameters, and `expressions` for separate-query expressions. Board permission
     tags default to every tag the view checks.
   - `api:` holds REST mocks for what the board JS fetches: read its `fetchRecords` / `getRecords` calls
     and give `display/<view>` arrays in that view's field names. `embeds:` gives data to embedded views.
   - The agency logo is platform data. Keep one `agency-logo.png` at the client repo root (PJF saves it
     from the live header) and every flow picks it up; otherwise the logo circle is blank.
   - Data per the "Data" section: real dev records by default, sample data with `--sample` / `--uat`.
     Fixtures (DOM edits) are a last resort; board JS may overwrite them.
   - If the render doesn't look right, check the dev guide's Network and console notes for the call that
     needs a mock before reaching for a fixture.
   - If a behaviour can't be produced this way, keep it in the text only.
5. **Render**: `node ~/code/webeoc-guide/bin/webeoc-guide.js render <name>-guide.yaml [--uat]`. A selector
   that matches nothing fails the run: fix the flow, or the view if the flow caught a real gap. The first
   time you render a view, add `--debug <scratch dir>` and look at the PNG to check the render looks right.
   `do:` steps act like a user: `select` opens the MDB dropdown and clicks the option, and `click` with
   `force: true` clicks a disabled control (e.g. to show a lock holding).
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

## Several tickets or streams at once: one guide, a section each

When one test round covers several tickets or streams (a combined test-push, a batch PJF tests together),
make **one** guide with a **separate section per ticket / stream**. Not one guide each, and not a single
blended flow that mixes their steps.

- Each stream writes its part as a standalone flow: its own scenes, scene-level `api` mocks, and scene names
  prefixed with its ticket key or card shortLink (`PSAPAC-1519 · Vaccinations`) and carrying
  `stream: <stream name>` (the dev guide's **MR & close out** works per stream), so the sections read
  apart in the guide and its step list. Each scene also gets `ticket: <shortLink | KEY>`, so each section
  shows its own ticket panel (once per run of scenes for the same ticket).
- The orchestrator merges those scenes, in ticket order, into one flow. It renders that flow against a
  board copy built from dev plus every stream's changed files, so the screens match what's live on the
  test platform. (`boardDir` is flow-level only, which is why the merged board copy is needed.)
- The "Scope" rules apply per section: each covers only its own ticket's changes or defects.
- With a combined test-push, set the merged flow's `testPush:` to the combined stream.
- **Render the combined guide into the repo's main checkout root** (`<repo>/<round>-guide.html`; `/*-guide.*`
  is git-excluded), never into `/tmp` or a Claude scratchpad: the helper only serves guides under `~`, and
  there Send to agent wakes the orchestrator and the toggle works.
- **Feedback on a combined guide comes to the orchestrator** (its pane is in that folder). Each item records
  its section (`[section: …]` in `webeoc-guide feedback`). Route each item to the stream that owns its section,
  replying at once with `respond … --pending --by <stream>` (the guide shows whether that stream is still
  working), then write that stream's answer back with `webeoc-guide respond` yourself, so PJF sees it in the guide.

## Feedback in the guide

Every guide has a feedback box under each step and a General section: PJF adds questions, change requests
and notes, then **Send to agent** saves them into the guide's HTML and asks the watching agent to act (**Save** is a draft). Re-renders keep them. When
PJF says there's feedback in a guide, or the orchestrator relays it, use the **guide-feedback** skill
(`webeoc-guide feedback` / `respond`); its watch mode acts on Send to agent as soon as PJF makes it. Mention the feedback box once, the first time you link a guide in a
stream: "Questions or changes? Add them in the guide and press Send to agent."

## Before/after toggle

In a stream worktree, the guide's sidebar shows a **Test platform (dev)** toggle once the stream is
test-pushed: it switches the platform between dev's version and the stream's build (`test-push before|after`,
claims kept) so the tester can compare. If the claims belong to a combined build (one test-push for several
streams), add `testPush: <that stream>` at the top of the flow file. Never press it on the tester's behalf.

## Skip it (one line saying why) when

- the flow isn't visual: list/group pushes, REST data scripts, server-side expressions only.
- the screen depends on data the flow can't sensibly mock (e.g. a large live dataset or a third-party
  integration), so the picture would mislead.

## Safety

The renderer never contacts WebEOC. `*.webeocasp.com` is refused even if allowlisted, because Imperva
rate-blocks tooling, and board REST calls only ever hit the `api` mocks (or a stub 404). Don't add WebEOC hosts
to `allowHosts`. Real dev records reach a guide only through the flow file, read beforehand (see "Data").
Sample-data guides (`--sample`, `--uat`) are safe to send to a tester; real-record dev guides stay internal.
