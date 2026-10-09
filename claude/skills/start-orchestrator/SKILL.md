---
name: start-orchestrator
description: Open (or re-lay-out) an orchestrator session window — tmux window in the repo's main checkout with three columns (shell left, Claude centre at 50%, nvim notes right), Claude started in bypass on /orchestrate (or /delegate). Invoke when PJF types /start-orchestrator, asks to "start/open an orchestrator", or asks to apply the stream layout to the orchestrator window.
argument-hint: '[--here] [--name <window>] [--scratch <file>]'
---

# /start-orchestrator

Starts the session that runs the **delegate** workflow (`/delegate`, and the repo's `/orchestrate` where
one exists). The window uses the same layout as the stream windows `delegate/spawn-stream.sh` opens, so
every window in the tmux session looks the same:

```
+---------+-------------------+---------+
|  shell  |  claude (50%)     |  nvim   |
|  (root) |                   | scratch |
+---------+-------------------+---------+
```

## New orchestrator window

Run from the repo's **main checkout** (not a worktree):

```bash
~/.claude/skills/start-orchestrator/spawn-orchestrator.sh [--name <window>] [--scratch <file>] [--mode bypass|plan|default] [--prompt <text>]
```

- Window name defaults to `<repo>-orchestrator`. Scratch file defaults to `orchestrator-scratch.md` in the
  repo root (created if missing; git-excluded via `/*-scratch.md`). agvic's existing one is
  `boards/agvic-ops/uat-orch-scratch.md`; pass it with `--scratch`.
- Claude starts in **bypass** by default. In any other mode, the messages streams send it are held for
  PJF's approval (see the orchestrate skill, "Opening a stream").
- First prompt defaults to `/orchestrate` if `.claude/skills/orchestrate` exists in the repo, else `/delegate`.

## Re-lay-out the current window (`--here`)

Inside an existing orchestrator session, run with `--here` from the Claude pane's Bash tool. It treats
`$TMUX_PANE` as the Claude column, reuses an existing shell and nvim pane (creating any that are missing),
and arranges shell | Claude 50% | nvim. Refuses windows with more than 3 panes.

## After it starts

Follow `/orchestrate` (repo protocol, state file) or `/delegate` (spawning streams, auto mode, test-push,
close-out). Target panes by the ids the script prints, never by index.
