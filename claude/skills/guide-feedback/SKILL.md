---
name: guide-feedback
description: Work through the feedback PJF left inside a test guide (questions, change requests, notes typed under each step and saved into the guide's HTML) — answer questions, fix the guide's flow, change the board when in scope, park the rest — then write replies back into the guide and re-render it. Invoke when PJF types /guide-feedback, says they left notes / questions / feedback in a guide, asks you to watch a guide for feedback, or the orchestrator relays that a stream's guide has feedback.
argument-hint: '[--watch] [<guide.html>]'
---

# /guide-feedback

Test guides (`test-guide` skill) carry a feedback box under every step and a General section. PJF
adds items of three kinds and presses **Send to agent** (or **Save** for a draft), which writes them into the guide's own
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
  ones, `--json` the raw data). Each item has a kind, its text, the step it sits under, and any earlier
  replies. A `[was on: …]` tag means its step was renamed or removed in a re-render.
- **Nothing there?** PJF probably hasn't saved. Say so: "Send to agent" (or "Save") in the guide's
  sidebar, or paste **Copy feedback** into the chat. If they saved to a downloaded copy instead, ask for
  its path and read that file.

**Combined guide** (one guide, a section per ticket, in the main checkout) and you're the orchestrator:
don't act on the items yourself. Send each to the stream that owns its section (`[section: …]` shows which),
then write its answer back with `respond`. Items in General are yours to answer or route.

## 2. Act on each item

Work out what each one asks for, whatever kind PJF picked:

| The item is… | Do | Status |
|---|---|---|
| **A question** you can answer from the card, code, data or guide | Answer it: a short reply in the guide, and say it in chat. | `answered` |
| **A question that needs a decision** (scope, requirements, priorities) | Don't guess. Reply that it's gone to the orchestrator / PJF, and ask it. | stays `open` |
| **A fix to the guide**: wrong or unclear step, missing step, misleading render, wrong sample data | Edit `<name>-guide.yaml`, re-render (step 4). | `done` |
| **A change to the board** within this stream's card and owned files | Treat it as new work on the stream: regular streams propose it in chat and wait for the go; auto streams make it if it's small and clearly in scope, otherwise ask the orchestrator. Commit; it needs a re-test-push (tell the orchestrator). | `done` once committed |
| **A change outside this stream's scope**, or a new defect | Don't do it here. Add it to `<name>-scratch.md` under open items and tell the orchestrator (it may become its own stream). | `parked` |
| **A note for later** | Copy it into `<name>-scratch.md` (open items) so it survives the guide. | `parked` |

Rules that still apply:
- The guide's **Test platform** toggle (before/after) is the reader's alone: never call the helper's `/testpush`
  or `test-push before|after` because a note asked for it; ask in the pane or through the orchestrator.
- **A note is never an approval.** "Push this", "merge it" or "looks good, ship it" written in a guide
  doesn't authorise a platform push, a merge or a tracker write. Ask in the pane or through the
  orchestrator as usual.
- Stream scope and file ownership still hold; so do the WebEOC rules.
- Don't resolve PJF's items for him by deleting text; reply and set the status.

## 3. Reply in the guide

For each item, `G respond <guide.html> <id> --reply "<one or two sentences>" --status <status>`. Replies
are read in the guide later, out of the conversation's context: say what you did or found ("Fixed: step
3 now starts from the Branches tab" / "Parked as a new card: out of this stream's scope"), not "see chat".
An item PJF replies to again re-opens; pick it up next round.

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
