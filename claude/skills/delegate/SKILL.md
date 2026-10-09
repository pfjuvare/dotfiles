---
name: delegate
description: Become the orchestrator for a set of tasks and delegate each one to its own work stream — a git worktree + tmux window (three columns: shell left, Claude centre at 50%, nvim scratch file right) + a fresh Claude session. Every stream runs one pipeline (plan → implement → subagent review → pre-MR test push → GitLab MR → merge-and-deploy → live re-test); regular mode starts in plan mode with PJF checkpoints (repro flow, plan approval), `--auto` runs hands-off in bypass and escalates to the orchestrator only when unclear. Invoke when PJF types /delegate, asks to "spin up worktrees/sessions/agents" for a list of tasks or Trello cards, or asks you to "act as orchestrator".
argument-hint: '[--auto [--notify [<channel>]]] <cards / tasks>'
---

# /delegate

You are the **orchestrator**. You split the work into streams, brief each one, launch it, and track it. You
**do not implement** — every edit belongs to exactly one stream's worktree. Your own writes are limited to
briefs, the state file, memory/Obsidian, and git plumbing (merge / worktree prune) on the main checkout.

The orchestrator session itself comes from **`/start-orchestrator`**: a window in the main checkout with the
stream layout (shell | Claude 50% | nvim scratch), bypass mode, opening on `/orchestrate` (or `/delegate`).
`--here` re-lays-out the current window.

If the repo has its own orchestrator skill (e.g. agvic's `.claude/skills/orchestrate/SKILL.md`), invoke it
too — its project rules (state file, dev branch, ownership) take precedence over the generic ones here.

## 1. Scope the streams

- Resolve the task list. For Trello cards, fetch them live (`ptc cards "<list>"`, `ptc card <shortLink>`)
  — don't trust snapshots. For "cards assigned to me", filter on `idMembers` against `ptc me`.
- If the scope is ambiguous (which lists, assigned vs unassigned, exclusions), ask ONE question with the
  counts before launching — spawning 5 streams vs 26 is a big difference.
- One stream per task. Check existing worktrees (`git worktree list`) for prior work on the same card and
  note any unmerged commits in that stream's brief.

## 2. Name each stream

- Trello card → `<prefix>-<shortLink>`, e.g. `uat-3sJx4mjm`. Prefix = the batch/category PJF uses
  (`uat`, `bug`, `feat`…); ask if not obvious.
- No card → short kebab slug, e.g. `npm-policy`.
- The name is used for the worktree dir (`.claude/worktrees/<name>`), the branch (`worktree-<name>`),
  and the scratch file (`<name>-scratch.md`).
- Also pick a **desc**: the most concise tag for the task — 1–2 kebab-case words, ≤12 chars, e.g.
  `workshops`, `pass-expiry`. Passed as `--desc`, it's appended to the tmux window name only
  (`uat-3sJx4mjm-workshops`) so the taskbar stays readable without crowding it.

## 3. Write the brief

**One pipeline, two modes.** Every stream runs the same pipeline: interpret → plan → implement → validate →
subagent review → **test gate** (test-push of the worktree build) → MR `mr/<name>` → approval →
merge-and-deploy → live re-test. The modes differ only in the **checkpoints**:

| | regular `/delegate` | `/delegate --auto` |
|---|---|---|
| session | plan mode, PJF in the pane | bypass, runs alone |
| repro flow (defects) | yes, waits for PJF | no |
| plan approval | ExitPlanMode, PJF approves | written to scratch, no wait |
| questions | asked in the pane | SendMessage orchestrator → relayed |
| test-push | orchestrator, after PJF says go | orchestrator, pre-authorised |
| MR | open-gitlab-mr, PJF confirms fields | pre-authorised (+ Teams under `--notify`) |

Write the brief to your scratchpad, then pass it to the spawn script (it lands as `STREAM-BRIEF.md` in the
worktree root — durable even if a cross-session message is lost). Regular template:

```markdown
# Stream brief — <name>

Trello card: `<shortLink>` (https://trello.com/c/<shortLink>). Worktree `.claude/worktrees/<name>`,
branch `worktree-<name>` (off <base>).

You are in **plan mode**. Do NOT edit files or implement anything yet.

1. Fetch the card with `ptc card <shortLink>` — description, checklists, ALL comments (newest often
   supersede the description).
2. *(Optional — include for defects / behaviour changes; omit for pure build tasks or if PJF opts out)*
   **Repro flow first.** Before investigating a fix, give PJF a concise testing flow for the problem AS IT
   STANDS: account/position + incident to use, numbered steps, expected vs actual (from the card, in your
   words). Add one line of how you read the problem. Then STOP and wait for him to confirm or correct it —
   this is to get his bearings and agree on the problem before any planning.
3. Investigate the relevant code in this worktree (read-only).
4. Decide:
   - **Clear problem, confident fix** → concrete plan (files, changes, verification) via ExitPlanMode.
   - **Unclear / can't confirm symptom or cause** → do NOT guess. Summarise what you understood, what's
     unclear, and the specific questions for PJF. He'll work with you directly.
5. Once approved: implement, validate (XML well-formedness, repo prettier on authored JS, project checks),
   commit with named files.
6. **Review**: a fresh subagent reviews `git diff <base-sha>..HEAD` against the card and the project rules
   (CLAUDE.md, memory). Fix confirmed findings; commit.
7. **Test gate**: give PJF a concise test flow here (position, steps, expected) + any table/list/group change
   he must push himself, and `SendMessage` the orchestrator (`<orchestrator-session>`) "ready to test" + the
   same flow. The orchestrator test-pushes your committed build once PJF says go. Fix → commit → tell it.
8. **MR** on PJF's go after testing: follow the open-gitlab-mr skill (source `mr/<name>`, target `<target>`,
   its description template). Once it's created, **offer PJF the Teams post** (open-gitlab-mr "Teams review
   request"), even when the go came relayed through the orchestrator. `SendMessage` the orchestrator the MR
   link and whether it was posted to Teams.
9. Be concise.

<confirmed requirements from PJF, if any — state them as requirements, not suggestions>

Rules: never push to the platform yourself (weboard, webeoc-lists, webeoc-groups — the orchestrator does test
pushes); no tracker writes without asking PJF; no merges into <base>. Never `git add -A`. Other streams run
in parallel (<list names>): flag any file you'd touch that another stream is likely to touch.
```

When PJF has already given you requirements for a task, confirm your understanding with him first, then put
the confirmed version in the brief.

Step 2 (repro flow) is plan-mode only and on by default for defects; drop it for build/feature tasks or when PJF
says skip (e.g. `/delegate --no-repro`). Auto mode never includes it — auto streams don't wait on PJF.

## 4. Launch

```bash
~/.claude/skills/delegate/spawn-stream.sh <name> --desc <desc> --brief <scratchpad>/<name>.md [--base <branch>] [--mode plan] [--ui tmux|vscode]
```

`--ui vscode` (or `DELEGATE_UI=vscode`) is for VS Code users: instead of a tmux window it opens the
worktree + scratch file in a new VS Code window and prints the `claude` command; tell the user to run it in
that window's terminal (the script can't start it there). Skip the `tmux capture-pane` check below and
confirm via `ListAgents` instead.

Run from the repo's **main checkout**. Base defaults to the main checkout's current branch — check the
project CLAUDE.md/memory for the correct dev branch (agvic: `dev`). The script creates the worktree +
branch, git-excludes `STREAM-BRIEF.md` and `/*-scratch.md`, opens the window in the current tmux session
with the 3-pane layout, opens nvim on the scratch file, and starts Claude:

- `--mode plan` (default): `claude --allow-dangerously-skip-permissions --permission-mode plan` — plans
  first; bypass is available for execution (choose it when approving the plan, or shift+tab).
- `--mode bypass`: straight to `--dangerously-skip-permissions` (only when the task is already fully planned).

Launch several streams in one Bash loop. Then ~20s later confirm each started:
`tmux capture-pane -p -t <claude pane id> | tail -5`. Use the claude pane id the script prints, never a pane index: Claude is the middle column, not pane 1.

## 5. Track

Record every stream in the state file (`.claude/orchestrator-state.md` in the main checkout, untracked):
name, card, base @ sha, status (`planning` / `executing` / `merged` / `CLOSED`), owned files once known.
Reconcile against `git worktree list`, `ListAgents`, and `tmux list-windows` before trusting it.

Talking to streams: `SendMessage` using names from `ListAgents`; ask for read-only status only. Never ask a
stream to push, pull, or merge on your behalf — that launders PJF's approval.

## Auto mode (`/delegate --auto …`)

Hands-off, end to end, for low-risk work (low-priority / UI-tweak cards). PJF only sees the MR — and a
question if something is genuinely unclear. Invoking `--auto` IS his authorisation for each auto stream to
push its own `mr/<name>` branch and open an MR (no per-push ask), for YOU to push the dev branch
(below), and for YOU to test-push each stream's build when it reports ready (see "Pre-MR test push"). Nothing else is pre-authorised — posting the MR to Teams needs `--notify [<channel>]` too
(default channel `code-reviews`): it adds a `Teams: <channel>` line to each auto brief.

- **Eligibility.** Before launching, sanity-check each card: if it's clearly not a small/UI change (data
  model, lists, permissions, cross-view workflows), say so and run it as a normal plan-mode stream instead.
- **Sync the dev branch first.** From the main checkout, fast-forward-push it so each stream's base is on
  the remote and its MR carries only its own commits: `git fetch origin <dev>` then, if
  `git merge-base --is-ancestor origin/<dev> <dev>`, `git push origin <dev>` (own Bash call; never
  `--force`). If it's not a fast-forward (someone else pushed), stop and tell PJF. Repeat before a stream
  opens its MR if the dev branch has moved since launch (e.g. another stream's work merged).
- **Launch** with `--mode bypass` and the auto brief below (swap it for the plan-mode instructions in §3).
- **You are the escalation point.** Streams `SendMessage` you questions. Answer yourself only when the
  card, repo, memory or an earlier PJF answer settles it; otherwise ask PJF (one line per question, card
  named) and relay his answer verbatim-in-substance. Never invent requirements to keep a stream moving.
- **Ready to test** = the stream sends you its test flow. Run `test-push.sh push <name>` (dry-run first),
  record status `testing`, and send PJF the test flow. (Regular streams: same, but only once PJF says go —
  he already has the flow in the stream's pane.) Relay his result: fixes → the stream commits and
  tells you → re-push; go → tell the stream to open its MR.
- **Done** = the stream sends you its MR link. Record it (status `mr-open !<iid>`) and tell PJF one line.
  Regular stream that didn't post to Teams → offer PJF the post in that line (`gitlab-mr.sh notify <iid>`).
  Streams never merge into the local dev branch (if `weboard dev` watches it, a merge auto-pushes).
- **Sync the dev branch for regular streams too** (their MRs need the same clean base) — but there the
  `git push origin <dev>` isn't pre-authorised: ask PJF first.

Auto brief (replaces steps 1–8 of the §3 template; the header and Rules stay):

```markdown
You are an **autonomous** stream (bypass mode). Take the card end to end without PJF:

1. `ptc card <shortLink>` — description, checklists, ALL comments (newest supersede). Interpret the
   requirement. If it's ambiguous, the symptom can't be confirmed from code, or the fix is a guess →
   `SendMessage` the orchestrator (`<orchestrator-session>`) with numbered questions, note them in
   `<name>-scratch.md`, and WAIT for the reply. Don't guess.
2. Write a short plan to `<name>-scratch.md` (files, changes, verification). Then implement it.
3. Validate (XML well-formedness, repo prettier on authored JS, project checks). Commit with named files.
4. **Review**: launch a fresh subagent to review `git diff <base-sha>..HEAD` against the card and the
   project rules (CLAUDE.md, memory). Fix confirmed findings; commit.
5. **Test gate**: `SendMessage` the orchestrator "ready to test" + a concise test flow (position, steps,
   expected) + any table/list change PJF must push himself. WAIT. The orchestrator test-pushes your
   committed build and PJF tests it. Fixes come back through the orchestrator: fix, commit, tell it
   (it re-pushes). Only on PJF's go → step 6. Never push to the platform yourself.
6. **MR**: follow the open-gitlab-mr skill in *pre-authorised* mode — source `mr/<name>`, target `<target>`.
   You may push ONLY `mr/<name>`. If the cherry-pick conflicts, stop and tell the orchestrator.
   Teams: <channel>   ← include only under `--notify`; the stream then posts the MR there
7. `SendMessage` the orchestrator: MR link + one line per change.

Hard limits: no platform pushes/pulls (weboard, webeoc-lists, webeoc-groups), no Trello/Jira writes, no
merges into <base>, no pushing any branch other than `mr/<name>`, never `git add -A`. If the work turns
out bigger than a small change, stop and tell the orchestrator.
```

## Pre-MR test push (`test-push.sh`)

Streams are tested on the platform from their own worktree before any MR, so a misread card is caught
before review. `~/.claude/skills/delegate/test-push.sh` (on PJF's PATH as `test-push` via a `~/.local/bin` symlink; run from the main checkout; `--help`):

- `push <name> [--dry-run]` — targeted `weboard push` of every asset the stream changed vs its merge-base
  with dev (resources → `Util - Schema - *` → views), from the worktree. Records a **claim** per asset in
  `.git/test-slots.tsv`.
- `status` — what's on the platform right now, per stream. Check it before telling PJF what he's testing.
- `release <name> [--restore]` — drop the claims; `--restore` re-pushes dev's version (rejected/abandoned).
- Merging is the normal release: `merge-and-deploy.sh` re-pushes the merged assets from dev and clears
  their claims.

**One live version per asset, not one worktree at a time.** Streams touching disjoint assets can be under
test together. `push` refuses an asset another stream claims (test → merge/release that one first), and
refuses when dev changed an asset since the stream branched (pushing would revert dev's work live — have
the stream `git merge dev` first). Tables and lists are listed, never pushed: PJF does those, before views.
Pushing is pre-authorised in `--auto` mode; otherwise ask PJF. Either way the script checks `weboard dev`.
A full `weboard push` (whole board from dev) overwrites every claimed asset: re-run `test-push push <name>` for
each stream in `test-push status` afterwards.

## Testing on the platform

Both modes test through `test-push.sh` from the stream's worktree (above) — the pre-MR build — and again
after merge-and-deploy on the dev build. The older path (commit in the worktree → fast-forward-merge into the
main checkout's dev branch while PJF runs `weboard dev`, which auto-pushes) is only for when PJF asks for it;
if a merged change isn't live there, check the watcher first.

## 6. Finish a stream

1. No-MR work only (PJF opted out of an MR): merge into the dev branch per his confidence-gated rule (clean,
   well-defined → merge; debugging-heavy or unverified → ask first), then skip to step 3.
2. **Post-merge flow** — once PJF approves the MR, run it without re-asking at each step:
   1. `merge-and-deploy.sh <iid> --dry-run`, then for real, from the main checkout on dev. It merges on
      GitLab, pulls the remote back into local dev (fast-forward), and `weboard push`es each changed view /
      resource (it also clears the stream's test-push claims).
   2. Relay what it printed: assets pushed, any "needs PJF" items (tables, lists, groups — ask), and the MR's
      **How to test** steps verbatim, so he re-tests the merged build live.
   3. On his OK → close the stream (step 3). A failed re-test → a fix stream (or the same stream, new MR).
3. Prune only when: the work is merged (for MR streams, check the MR, since `mr/<name>` is cherry-picked),
   `test-push status` shows no claims for it, the worktree is clean (scratch files aside), and its
   `<name>-scratch.md` has no parked or open items (read it; carry live ones into the project's open list).
   Then close the tmux window, `git worktree remove`, delete the local branch, mark the stream `CLOSED` in the
   state file (keep the section), and log it wherever the project records completed work. The project's
   orchestrator skill may have a fuller checklist (agvic: orchestrate → "Closing a stream").

## Reporting to PJF

One line per stream (name — card title — status/next action). Lead with what he must act on. No method
narration.
