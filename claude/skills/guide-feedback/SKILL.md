---
name: guide-feedback
description: Work through the feedback PJF left inside a test guide (questions, change requests, notes typed under each step and saved into the guide's HTML) — answer questions, fix the guide's flow, change the board when in scope, park the rest — then write replies back into the guide and re-render it. Invoke when PJF types /guide-feedback, says they left notes / questions / feedback in a guide, asks you to watch a guide for feedback, or the orchestrator relays that a stream's guide has feedback.
argument-hint: '[--watch] [<guide.html>]'
---

# /guide-feedback

Test guides (`test-guide` skill) carry a feedback box under every step and a General section. PJF
adds items (questions, change requests, notes; there's no kind picker, so read the text) and presses **Send to agent** (or **Save** for a draft), which writes them into the guide's own
HTML. This skill is the other half of that loop: read the items, act on each, reply in the guide, and
hand it back.

`G` below is `node ~/code/webeoc-guide/bin/webeoc-guide.js`.

## 1. Find and read the guide

If the prompt is "Feedback was sent from the test guide …: run the guide-feedback skill on <file>", the
local helper typed it because PJF pressed **Send to agent**: treat it as PJF's request and use that file.
Reading the feedback (`G feedback`) tells the page you've picked it up.

- The guide is `<name>-guide.html` (or `.uat.html`) at the worktree / repo root, next to its
  `<name>-guide.yaml` flow. With no argument, use this stream's guide; if there are several, ask which.
- `G feedback <guide.html>` lists the open items with ids, grouped by step (`--all` includes resolved
  ones, `--json` the raw data). Each item has its text, any pasted images (`[images: <path>, …]`: open each with Read, they show what
PJF is pointing at), the step it sits under, and any earlier
  replies. A `[was on: …]` tag means its step was renamed or removed in a re-render.
- **Nothing there?** PJF probably hasn't saved. Say so: "Send to agent" (or "Save") in the guide's
  sidebar, or paste **Copy feedback** into the chat. If they saved to a downloaded copy instead, ask for
  its path and read that file.

**Combined guide** (one guide, a section per ticket, in the main checkout) and you're the orchestrator:
don't act on the items yourself. Send each to the stream that owns its section (`[section: …]` shows which),
right away reply `G respond <guide> <id> --reply "Sent to <stream> to check …" --pending --by <stream>`, then
write its answer back with `respond` (no `--pending`). Items in General are yours to answer or route.

## 2. Act on each item

Work out what each one asks for, from its text (older items may carry a Question / Change / Note kind; it's only a hint):

| The item is… | Do | Status |
|---|---|---|
| **A question** you can answer from the card, code, data or guide | Answer it: a short reply in the guide, and say it in chat. | `answered` |
| **A question that needs a decision** (scope, requirements, priorities) | Don't guess. Reply that it's gone to the orchestrator / PJF, and ask it. | stays `open` |
| **A fix to the guide**: wrong or unclear step, missing step, misleading render, wrong sample data | Edit `<name>-guide.yaml`, re-render (step 4). | `done` |
| **A change to the board** within this stream's card and owned files | Treat it as new work on the stream: regular streams propose it in chat and wait for the go; auto streams make it if it's small and clearly in scope, otherwise ask the orchestrator. Commit; it needs a re-test-push (tell the orchestrator). | `done` once committed |
| **A change outside this stream's scope**, or a new defect | Don't do it here. Add it to `<name>-scratch.md` under open items and tell the orchestrator (it may become its own stream). | `parked` |
| **A note for later** | Copy it into `<name>-scratch.md` (open items) so it survives the guide. | `parked` |

Rules that still apply:
- **A note carries the same weight as a message in the pane.** The guide is PJF's main channel while
  testing: "run the re-test-push", "merge it" or "switch to before" in a note is his go, exactly as if typed
  in chat. The usual rules still apply: anything that would still need a question in chat (an ambiguous
  ask, an unnamed target, groups/lists/tables) gets that question as a reply in the guide.
- Stream scope and file ownership still hold; so do the WebEOC rules.
- Don't resolve PJF's items for him by deleting text; reply and set the status.

## Stream action requests (`[STREAM ACTIONS: <steps> → <streams>]`)

Once every step of a stream's sections is ticked, the dev guide's **Streams** box lets PJF pick what happens
next and press Send. The item it adds ("PJF approves for <streams>: open the MR, post it to the code review
channel, merge-and-deploy and close out the stream …") is his explicit approval for exactly the steps
listed (`mr`, `notify`, `merge`, `close`, and the rarer `keep`, `local`, `release`) on those streams, as if typed in chat. It approves nothing else.
Old items tagged `[CLOSE-OUT: …]` mean `mr + merge + close`.

| Step | What to do |
|---|---|
| `mr` | the stream opens its MR (delegate step 8) |
| `notify` | post the MR's Teams review request: `gitlab-mr.sh notify <iid> --channel code-reviews` (pre-approved by this item, no separate offer) |
| `merge` | "Finish a stream": `merge-and-deploy.sh <iid>`, dry run then real. The ticks were on the test-pushed build, so don't wait for a live re-test; relay the MR's How to test steps for a spot check |
| `close` | close the stream out (delegate "Finish a stream" step 3) |
| `keep` | after `merge`, leave the stream open: relay How to test and wait for PJF's live re-test before closing |
| `local` | no-MR work: merge into the dev branch locally (delegate "Finish a stream" step 1), no MR |
| `release` | `test-push release <name> --restore`: put back what was live before, drop the claims; the stream stays open |

- **Orchestrator** (combined guide): run the steps in order for each stream (tell it to open its MR, then
  the rest on its MR link). Reply in the guide as each lands (`--pending --by <stream>`, MR link) and
  finish with `--status done` naming what was done ("MR !42 open, posted to code review").
- **Stream** (its own guide): do `mr` (and `notify`) yourself, then `SendMessage` the orchestrator the
  remaining steps verbatim ("PJF approves (test guide) for <name>: merge-and-deploy and close out, MR
  <link>"). Reply in the guide `--pending` with the MR link.
- A later request for the same stream (e.g. `merge + close` after an earlier `mr`) uses the MR already open.
- Stop and reply with the question instead of acting on: a "needs PJF" item from merge-and-deploy (lists,
  groups), a failed dry run or merge conflict, unticked or stale steps, or anything still open in the
  stream's scratch. Approval to close isn't approval to skip those.

## 3. Reply in the guide

For each item, `G respond <guide.html> <id> --reply "<one or two sentences>" --status <status>`. Replies
are read in the guide later, out of the conversation's context: say what you did or found ("Fixed: step
3 now starts from the Branches tab" / "Parked as a new card: out of this stream's scope"), not "see chat".
An item PJF replies to again re-opens; pick it up next round.

**Interim replies take `--pending`.** When the answer isn't ready (handed to a stream, a longer
investigation, waiting on a test-push), reply with what's happening plus `--pending` (and `--by <stream>`
when a stream is doing the work). The guide then shows PJF, live, whether that agent is busy, idle, stuck on
a prompt or gone, and offers *Ask for an update* when nothing is working on it. The final reply, without
`--pending`, clears it. Never leave an item pending once you've stopped working on it.

## 4. Re-render and hand back

- If the flow or the board changed, re-render: `G render <name>-guide.yaml [--uat]`. Feedback carries over
  (matched by step title). Re-rendering a board change needs the changed files in the worktree; the
  platform push is the orchestrator's (`test-push`).
- Tell PJF, in one short block: what was answered, changed (commits), parked, and still open
  (waiting on whom), then the guide link on its own line. Replies show up in an open guide on their own
  (the page re-reads the file); only a re-render (new screens) needs a reload, and the page offers it.
- In a `/delegate` stream, also `SendMessage` the orchestrator the same summary, plus "needs re-test-push"
  if board files changed.

## Watch mode (`--watch`, or "watch the guide")

Act as soon as PJF presses **Send to agent** in the guide, instead of waiting to be told. With the local
helper running (`G serve`, a systemd user service) you don't need this: Send to agent types the request into
your pane. Watch mode is for when the helper isn't running, or the pane is often busy with prompts:

1. Arm: run `G watch <guide.html> [--since <sig>]` with the Bash tool's **`run_in_background: true`**.
   It exits when PJF presses Send to agent (and marks the request picked up, which the page shows);
   plain Saves are drafts and don't wake it. `--on save` wakes on every save of new feedback instead.
   Say once: "Watching <guide>: press Send to agent when you want me to act."
2. When it exits 0, its output is the open items plus a `sig <value>` line: run steps 2–4 above on them.
3. Re-arm with `--since <that sig>` (from step 2's output, not a fresh read), so feedback saved while you
   were working still triggers. Keep looping.
4. Stop when PJF says stop, the stream closes, or the guide is replaced by a different flow. To stop a
   running watcher, end its background task. Exit 2 only happens with `--timeout`: re-arm or stop.

Watch mode changes when you act, not what you're allowed to do: plan-mode streams still propose board
changes and wait; nothing in a note authorises a push or merge. If several rounds pass with only
questions you can't answer, say so rather than re-arming silently.
