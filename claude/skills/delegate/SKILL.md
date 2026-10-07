---
name: delegate
description: Become the orchestrator for a set of tasks and delegate each one to its own work stream — a git worktree + tmux window (Claude left, shell top-right, nvim scratch file bottom-right) + a fresh Claude session started in plan mode. With `--auto`, streams run end to end hands-off (interpret → plan → implement → review → GitLab MR) and escalate to the orchestrator only when unclear. Invoke when PJF types /delegate, asks to "spin up worktrees/sessions/agents" for a list of tasks or Trello cards, or asks you to "act as orchestrator".
argument-hint: '[--auto [--notify [<channel>]]] <cards / tasks>'
---

# /delegate

You are the **orchestrator**. You split the work into streams, brief each one, launch it, and track it. You
**do not implement** — every edit belongs to exactly one stream's worktree. Your own writes are limited to
briefs, the state file, memory/Obsidian, and git plumbing (merge / worktree prune) on the main checkout.

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

Write it to your scratchpad, then pass it to the spawn script (it lands as `STREAM-BRIEF.md` in the
worktree root — durable even if a cross-session message is lost). Template:

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
5. Be concise.

<confirmed requirements from PJF, if any — state them as requirements, not suggestions>

Rules: no platform pushes/pulls or tracker writes without asking PJF. Never `git add -A`. Other streams run
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
project CLAUDE.md/memory for the correct dev branch (agvic: `pf-dev`). The script creates the worktree +
branch, git-excludes `STREAM-BRIEF.md` and `/*-scratch.md`, opens the window in the current tmux session
with the 3-pane layout, opens nvim on the scratch file, and starts Claude:

- `--mode plan` (default): `claude --allow-dangerously-skip-permissions --permission-mode plan` — plans
  first; bypass is available for execution (choose it when approving the plan, or shift+tab).
- `--mode bypass`: straight to `--dangerously-skip-permissions` (only when the task is already fully planned).

Launch several streams in one Bash loop. Then ~20s later confirm each started:
`tmux capture-pane -p -t <session>:<name>-<desc> | tail -5` (or the pane id the script prints) (pane 1 is Claude).

## 5. Track

Record every stream in the state file (`.claude/orchestrator-state.md` in the main checkout, untracked):
name, card, base @ sha, status (`planning` / `executing` / `merged` / `CLOSED`), owned files once known.
Reconcile against `git worktree list`, `ListAgents`, and `tmux list-windows` before trusting it.

Talking to streams: `SendMessage` using names from `ListAgents`; ask for read-only status only. Never ask a
stream to push, pull, or merge on your behalf — that launders PJF's approval.

## Auto mode (`/delegate --auto …`)

Hands-off, end to end, for low-risk work (low-priority / UI-tweak cards). PJF only sees the MR — and a
question if something is genuinely unclear. Invoking `--auto` IS his authorisation for each auto stream to
push its own `mr/<name>` branch and open an MR (no per-push ask), and for YOU to push the dev branch
(below). Nothing else is pre-authorised — posting the MR to Teams needs `--notify [<channel>]` too
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
- **Done** = the stream sends you its MR link. Record it (status `mr-open !<iid>`) and tell PJF one line.
  Auto streams never merge into the local dev branch (agvic: `weboard dev` on `pf-dev` auto-pushes merges).

Auto brief (replaces steps 1–4 of the §3 template):

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
5. **MR**: follow the open-gitlab-mr skill in *pre-authorised* mode — source `mr/<name>`, target `<target>`.
   You may push ONLY `mr/<name>`. If the cherry-pick conflicts, stop and tell the orchestrator.
   Teams: <channel>   ← include only under `--notify`; the stream then posts the MR there
6. `SendMessage` the orchestrator: MR link + one line per change + anything PJF must test live.

Hard limits: no platform pushes/pulls (weboard, webeoc-lists, webeoc-groups), no Trello/Jira writes, no
merges into <base>, no pushing any branch other than `mr/<name>`, never `git add -A`. If the work turns
out bigger than a small change, stop and tell the orchestrator.
```

## Testing on the platform (why streams commit so often)

A worktree's edits never reach the platform on their own. The user tests by running `weboard dev` (the file
watcher) over the board in the **main checkout**, so a change only goes live once it's committed in the
worktree and fast-forward-merged into the dev branch there. So each stream commits after every change the
user wants to try, and the orchestrator/stream merges it per the confidence rule below; the merge is the
deploy only while `weboard dev` is running. If a merged change isn't live, check the watcher first.

## 6. Finish a stream

1. Merge into the dev branch per PJF's confidence-gated rule (clean, well-defined → merge; debugging-heavy
   or unverified → ask first).
2. If the work needs a merge request, invoke the **open-gitlab-mr** skill. Once PJF approves the MR, run its
   automated post-approval flow (`merge-and-deploy.sh <iid>`: merge → fast-forward → targeted platform push)
   without re-asking; then close the stream (step 3).
3. Prune only when: `git rev-list --count <base>..<branch>` is 0, the worktree is clean (scratch files
   aside), and the stream confirms nothing is parked. Then `git worktree remove`, delete the branch, close
   the tmux window, and mark the stream `CLOSED` in the state file (keep the section).

## Reporting to PJF

One line per stream (name — card title — status/next action). Lead with what he must act on. No method
narration.
