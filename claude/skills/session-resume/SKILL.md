---
name: session-resume
description: Orient at the start of a session by reading the Resume here block from the project's Obsidian hub note and surfacing Last session / Current focus / Next steps / Blockers to the user. Invoke when the user types /session-resume, /resume, "where did we leave off", "pick up where we left off", or at the start of any substantive session before diving into work. See ~/obsidian-vault/claude project hub note.md for the hub pattern.
---

# Session resume ritual

Orients Claude and the user at the start of a session using the Obsidian hub note. Only applies to projects following the hub-note pattern (see `~/obsidian-vault/claude project hub note.md`).

## Steps

1. **Locate the hub note.** Read the project's `CLAUDE.md` and find the "Long-term documentation hub" section — it names the exact path. If none is configured, tell the user the pattern isn't set up and suggest the bootstrap prompt in `~/obsidian-vault/claude project hub note.md`. Do not proceed.

2. **Read the hub note.** Focus on the `# Resume here` block — that's the load-bearing part. Skim the rest only if the user's likely next request needs it.

3. **Surface `Resume here`** to the user, concisely. Show Last session, Current focus, Next steps, and any Blockers. Light formatting is fine; don't dump the raw markdown.

4. **Check for leftover working state.** Run `git status` (and `git log @{u}..` if there's an upstream). If the tree is dirty or the branch is ahead of remote, flag it alongside the Resume output — it's either unfinished work from the previous session that the session-end ritual missed, or intentional WIP. Either way, surface it so the user can decide before diving in.

5. **Offer the next action** — propose starting on the first `Next steps` item, unless there's a blocker or leftover working state, in which case raise that first.

6. **Stop there.** Don't start work until the user confirms — they might want to redirect.

## Principles

- Keep it short. The whole point is a fast orient, not a full briefing.
- If Resume here looks stale (e.g. "Last session" is weeks old, or current focus contradicts the user's opening message), mention it — the session-end ritual may have been missed last time.
