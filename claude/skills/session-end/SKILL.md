---
name: session-end
description: Run the end-of-session ritual — update the Resume here block (Last session / Current focus / Next steps / Blockers) in the project's Obsidian hub note, plus append to Progress log and Decisions if warranted. Invoke when the user signals end of session explicitly ("wrap up", "end this session", "done for now", "let's stop") or implicitly ("thanks, that's all", "see you tomorrow", "I'm heading out"), when a significant unit of work completes with no implied follow-up (proactive — don't wait to be asked), or when the user asks for a checkpoint ("update resume", "checkpoint"). See ~/obsidian-vault/claude project hub note.md for the hub pattern.
---

# Session end ritual

Updates the Obsidian hub note so a cold future session can resume without context loss. Only applies to projects following the hub-note pattern (see `~/obsidian-vault/claude project hub note.md`).

## Steps

1. **Locate the hub note.** Read the project's `CLAUDE.md` and find the "Long-term documentation hub" section — it names the exact path, e.g. `~/obsidian-vault/01 projects/01 active/<project>/<project>.md`. If the project has no such section, tell the user the pattern isn't set up yet and suggest running the bootstrap prompt from `~/obsidian-vault/claude project hub note.md`. Do not proceed.

2. **Read the hub note** so you know current Resume here / Tasks / Progress log / Decisions state.

3. **Overwrite `# Resume here`** — do not append. Fill:
   - **Last session (YYYY-MM-DD):** one sentence on what we actually did this session. Use today's date.
   - **Current focus:** what's in progress right now, or "idle" if nothing is
   - **Next steps:** 1–3 concrete, ordered actions for the next session
   - **Blockers / open questions:** anything waiting on the user, unresolved, or needing a decision

4. **Append to `# Progress log`** only if something notable changed this session. Format: `**YYYY-MM-DD** — one-line summary`. Skip trivial changes — these are cues for the next session, not a changelog.

5. **Append to `# Decisions`** if any meaningful product/architectural/trade-off decision was made this session. Format: `**YYYY-MM-DD** — decision — why`. Lead with the why.

6. **Prune `# Tasks`**: tick off anything completed this session and remove anything clearly obsolete. When removing a completed task, confirm its completion is captured somewhere — a Progress log entry or the session's git commits. If neither covers it, tick it off (`[x]`) instead of deleting, so there's a trail of what got done.

7. **Check for uncommitted work.** Run `git status` (and `git log @{u}..` if there's an upstream). If the working tree is dirty or the branch is ahead of remote, surface this to the user in the closing confirmation — name the affected files / unpushed commits and ask whether to commit, push, or leave as-is. **Do not commit or push without explicit confirmation** — users often leave WIP (debug scaffolding, experiments) uncommitted on purpose. The goal is to prevent silent loss of context between sessions, not to take action.

8. **Confirm briefly** — one or two sentences telling the user what was updated. Don't quote the whole Resume block back at them. Include the uncommitted-work flag from step 7 if applicable.

## Principles

- `Resume here` is written for a cold future reader who wasn't in this conversation — be explicit, no in-jokes or pronouns-without-referents.
- If nothing notable happened, the Resume block still needs to be accurate — at minimum update "Last session" and confirm "Current focus" and "Next steps" still reflect reality.
- Don't touch sub-notes (`<project> - <topic>.md`) unless there's a reason; if the branching rule suggests splitting a section, flag it to the user instead of doing it silently.
