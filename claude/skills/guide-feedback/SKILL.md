---
name: guide-feedback
description: Work through the feedback PJF left inside a test guide (questions, change requests, notes typed under each step and saved into the guide's HTML) — answer questions, fix the guide's flow, change the board when in scope, park the rest — then write replies back into the guide and re-render it. Invoke when PJF types /guide-feedback, says they left notes / questions / feedback in a guide, or the orchestrator relays that a stream's guide has feedback.
argument-hint: '[<guide.html>]'
---

# /guide-feedback

Test guides (`test-guide` skill) carry a feedback box under every step and a General section. PJF
adds items of three kinds and clicks **Save feedback to file**, which writes them into the guide's own
HTML. This skill is the other half of that loop: read the items, act on each, reply in the guide, and
hand it back.

`G` below is `node ~/code/webeoc-guide/bin/webeoc-guide.js`.

## 1. Find and read the guide

- The guide is `<name>-guide.html` (or `.uat.html`) at the worktree / repo root, next to its
  `<name>-guide.yaml` flow. With no argument, use this stream's guide; if there are several, ask which.
- `G feedback <guide.html>` lists the open items with ids, grouped by step (`--all` includes resolved
  ones, `--json` the raw data). Each item has a kind, its text, the step it sits under, and any earlier
  replies. A `[was on: …]` tag means its step was renamed or removed in a re-render.
- **Nothing there?** PJF probably hasn't saved. Say so: "Save feedback to file" in the guide's
  sidebar, or paste **Copy feedback** into the chat. If they saved to a downloaded copy instead, ask for
  its path and read that file.

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
  (waiting on whom), then the guide link on its own line, and **reload the guide** to see the replies.
- In a `/delegate` stream, also `SendMessage` the orchestrator the same summary, plus "needs re-test-push"
  if board files changed.
