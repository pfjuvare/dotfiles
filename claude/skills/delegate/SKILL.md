---
name: delegate
description: Become the orchestrator for a set of tasks and delegate each one to its own work stream — a git worktree + tmux window (Claude left, shell top-right, nvim scratch file bottom-right) + a fresh Claude session started in plan mode. Invoke when PJF types /delegate, asks to "spin up worktrees/sessions/agents" for a list of tasks or Trello cards, or asks you to "act as orchestrator".
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
- The name is used for the tmux window, the worktree dir (`.claude/worktrees/<name>`), the branch
  (`worktree-<name>`), and the scratch file (`<name>-scratch.md`).

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
2. Investigate the relevant code in this worktree (read-only).
3. Decide:
   - **Clear problem, confident fix** → concrete plan (files, changes, verification) via ExitPlanMode.
   - **Unclear / can't confirm symptom or cause** → do NOT guess. Summarise what you understood, what's
     unclear, and the specific questions for PJF. He'll work with you directly.
4. Be concise.

<confirmed requirements from PJF, if any — state them as requirements, not suggestions>

Rules: no platform pushes/pulls or tracker writes without asking PJF. Never `git add -A`. Other streams run
in parallel (<list names>): flag any file you'd touch that another stream is likely to touch.
```

When PJF has already given you requirements for a task, confirm your understanding with him first, then put
the confirmed version in the brief.

## 4. Launch

```bash
~/.claude/skills/delegate/spawn-stream.sh <name> --brief <scratchpad>/<name>.md [--base <branch>] [--mode plan]
```

Run from the repo's **main checkout**. Base defaults to the main checkout's current branch — check the
project CLAUDE.md/memory for the correct dev branch (agvic: `pf-dev`). The script creates the worktree +
branch, git-excludes `STREAM-BRIEF.md` and `/*-scratch.md`, opens the window in the current tmux session
with the 3-pane layout, opens nvim on the scratch file, and starts Claude:

- `--mode plan` (default): `claude --allow-dangerously-skip-permissions --permission-mode plan` — plans
  first; bypass is available for execution (choose it when approving the plan, or shift+tab).
- `--mode bypass`: straight to `--dangerously-skip-permissions` (only when the task is already fully planned).

Launch several streams in one Bash loop. Then ~20s later confirm each started:
`tmux capture-pane -p -t <session>:<name> | tail -5` (pane 1 is Claude).

## 5. Track

Record every stream in the state file (`.claude/orchestrator-state.md` in the main checkout, untracked):
name, card, base @ sha, status (`planning` / `executing` / `merged` / `CLOSED`), owned files once known.
Reconcile against `git worktree list`, `ListAgents`, and `tmux list-windows` before trusting it.

Talking to streams: `SendMessage` using names from `ListAgents`; ask for read-only status only. Never ask a
stream to push, pull, or merge on your behalf — that launders PJF's approval.

## 6. Finish a stream

1. Merge into the dev branch per PJF's confidence-gated rule (clean, well-defined → merge; debugging-heavy
   or unverified → ask first).
2. If the work needs a merge request, invoke the **open-gitlab-mr** skill.
3. Prune only when: `git rev-list --count <base>..<branch>` is 0, the worktree is clean (scratch files
   aside), and the stream confirms nothing is parked. Then `git worktree remove`, delete the branch, close
   the tmux window, and mark the stream `CLOSED` in the state file (keep the section).

## Reporting to PJF

One line per stream (name — card title — status/next action). Lead with what he must act on. No method
narration.
