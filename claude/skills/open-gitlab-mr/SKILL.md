---
name: open-gitlab-mr
description: Open a GitLab merge request for the current repo via the GitLab REST API — gathers source/target branch, title and description from PJF, confirms, then creates the MR and returns its URL. Invoke when PJF types /open-gitlab-mr, asks to "open/raise/create an MR", or when a delegated stream is finished and needs a merge request.
---

# /open-gitlab-mr

Creating an MR is **outward-facing** (colleagues see it; it may trigger CI/notifications). Never create one
without PJF confirming the final fields in this conversation.

Helper: `~/.claude/skills/open-gitlab-mr/gitlab-mr.sh` (curl + jq; host/project derived from `origin`).

## Steps

1. **Preflight.** From the repo, run `gitlab-mr.sh check`. If it reports no token, stop and tell PJF the
   one-time setup: create an `api`-scope PAT at `https://<host>/-/user_settings/personal_access_tokens`,
   then `GITLAB_TOKEN=<token>` in `~/.config/gitlab/<host>.env` (chmod 600). Don't ask him to paste the
   token into chat.

2. **Scope = the stream's commits only (default).** When the MR is for a worktree stream / card, it must
   carry ONLY that stream's commits — never the whole dev branch (e.g. agvic `pf-dev`, which holds other
   streams' unreviewed work). Pushing the worktree branch as-is does NOT achieve this: it was branched
   off pf-dev, so it inherits every pf-dev commit not yet on the target. Instead:
   - Stream commits = `git log --no-merges <branch-point>..<worktree-branch>`, where branch-point is
     `git merge-base <worktree-branch> pf-dev` *as recorded at stream start* (STREAM-BRIEF "off pf-dev @
     <sha>") — after a fast-forward merge into pf-dev the merge-base is the stream tip, so use the brief.
   - Build `mr/<card>` off `origin/<target>` and cherry-pick those commits (use a throwaway worktree —
     never switch branches in the main checkout). Dry-check first with
     `git merge-tree --write-tree --merge-base=<parent-of-commit> origin/<target> <commit>`; on conflict,
     stop and tell PJF — the stream may depend on pf-dev commits not yet on the target.
   - **Shortcut:** if the branch-point is already on the remote (`git merge-base --is-ancestor <branch-point>
     origin/<target>` — e.g. the orchestrator pushed the dev branch at launch), skip the cherry-pick and just
     push the worktree branch as `mr/<card>` (`git push origin <worktree-branch>:mr/<card>`).
   - The source branch is then `mr/<card>`. Only MR the whole of pf-dev if PJF explicitly asks for it.

3. **Propose the fields**, pre-filled, in one short message and ask him to confirm or edit:
   - **Source branch** — the `mr/<card>` branch from step 2 (or the current branch for non-stream work).
   - **Target branch** — default to wherever this source branch's previous MRs went (agvic: `pf-dev` →
     `dev`, NOT `main`). Look it up: `gitlab-mr.sh recent <source>`. Else the project default branch.
   - **Title** — from the card title / commit subjects; imperative, ≤ 72 chars.
   - **Description** — draft from `git log --no-merges origin/<target>..<source>` (after step 2 this is only the stream's commits) and any Trello card: summary,
     changes (one line per area), how to test, card link. Write it to
     `<scratchpad>/mr-description.md` and tell PJF the path so he can edit it in nvim if he prefers.
   - **Options** — draft? delete source branch on merge? (default: no / no).
   Also run `gitlab-mr.sh existing <source> <target>`; if an open MR already exists, show it and ask
   whether to stop instead.

4. **Source branch must be on the remote.** Check with `git ls-remote --heads origin <source>` and
   `git rev-list --count origin/<source>..<source>`. If it's missing or behind, **ask** before pushing —
   pushing is a separate confirmation from creating the MR. Respect project push rules (e.g. agvic's
   remote must be SSH).

5. **Dry run, then create** once PJF confirms:
   ```bash
   gitlab-mr.sh create --source <s> --target <t> --title "<title>" --description-file <f> [--draft] [--remove-source] --dry-run
   gitlab-mr.sh create --source <s> --target <t> --title "<title>" --description-file <f> [--draft] [--remove-source]
   ```
   Report the `!iid` and URL — one line.

## WAF gotcha (gitlab.juvare.com)

The AWS load balancer in front of gitlab.juvare.com 403s (HTML page, `server: awselb/2.0`) any request body with a
quote directly followed by a dash — `'- User'`, `"- User"`, `" - User"` — it looks like an SQL-comment injection.
Seen on the MR title. Never put `'` or `"` immediately before `-` in titles/descriptions; drop the quotes or use
backticks. An HTML 403 (not GitLab JSON) = the WAF, not the token.

## Approved → merge, pull, deploy (automated)

When PJF says an MR is approved / "merge it" / "looks fine", run the whole post-approval flow without
re-asking at each step — his approval covers merge + fast-forward + targeted `weboard push`:

```bash
~/.claude/skills/open-gitlab-mr/merge-and-deploy.sh <iid> --dry-run   # show what will merge/push
~/.claude/skills/open-gitlab-mr/merge-and-deploy.sh <iid>             # do it
```

Run from the repo's main checkout on the MR's target branch. It merges (skips if already merged), fast-forwards
the local target branch, and `weboard push`es each board asset the MR's merge commit changed — one asset per
call, from the board dir — after checking `weboard dev` isn't running. It stops without pushing on: tracked
changes, non-mergeable MR, a local branch that can't fast-forward (local-only commits → merge by hand, tell
PJF), `weboard dev` running, or any push not reporting success (push errors are never non-blocking).

New assets push fine by name (resources are pushed before views). Still needs PJF's explicit go (the script lists
them as "needs PJF" and doesn't push them): `board-tables/` schema changes, `lists/` (webeoc-lists — destructive), and webeoc-groups changes (e.g. permission
renames → re-grant; `push --overwrite` is non-atomic). Report: merged sha, assets pushed, needs-PJF items, and
the MR's live test steps.

Lower-level: `gitlab-mr.sh status <iid>` / `gitlab-mr.sh merge <iid>`.

## Pre-authorised mode (auto delegate streams)

When the stream's `STREAM-BRIEF.md` says it's an autonomous `/delegate --auto` stream, PJF has already
authorised the push + MR. Run steps 1, 2, 4, 5 without asking: push only `mr/<name>` (never the dev or
target branch), title from the card, description to your session scratchpad `mr-description.md`
(never in the worktree), no draft, don't remove source. If `existing` finds an open MR for the pair,
push the updated branch and don't create a new one. Any failure (no token, conflict, push rejected) → stop
and report to the orchestrator; don't work around it.

## Not yet built

Posting a code-review request to Teams ("Pat's agent wrote this message") — deferred by PJF. Likely route:
a Teams incoming webhook / Workflows URL stored in `~/.config/teams/*.env`, called after step 4 with the
MR link. Outward-facing: confirm-first like the MR itself.
