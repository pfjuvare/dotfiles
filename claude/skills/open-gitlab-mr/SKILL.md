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
   carry ONLY that stream's commits — never the whole dev branch (whatever the project's dev branch is — it may hold other
   streams' unreviewed work). Pushing the worktree branch as-is does NOT achieve this: it was branched
   off the dev branch, so it inherits every dev-branch commit not yet on the target. Instead:
   - Stream commits = `git log --no-merges <branch-point>..<worktree-branch>`, where branch-point is
     `git merge-base <worktree-branch> <dev>` *as recorded at stream start* (STREAM-BRIEF "off <dev> @
     <sha>") — after a fast-forward merge into the dev branch the merge-base is the stream tip, so use the brief.
   - Build `mr/<card>` off `origin/<target>` and cherry-pick those commits (use a throwaway worktree —
     never switch branches in the main checkout). Dry-check first with
     `git merge-tree --write-tree --merge-base=<parent-of-commit> origin/<target> <commit>`; on conflict,
     stop and tell PJF — the stream may depend on dev-branch commits not yet on the target.
   - **Shortcut:** if the branch-point is already on the remote (`git merge-base --is-ancestor <branch-point>
     origin/<target>` — e.g. the orchestrator pushed the dev branch at launch), skip the cherry-pick and just
     push the worktree branch as `mr/<card>` (`git push origin <worktree-branch>:mr/<card>`).
   - The source branch is then `mr/<card>`. Only MR the whole dev branch if PJF explicitly asks for it. (agvic: streams branch off `dev` and
     target `dev`, so the shortcut normally applies.)

3. **Propose the fields**, pre-filled, in one short message and ask him to confirm or edit:
   - **Source branch** — the `mr/<card>` branch from step 2 (or the current branch for non-stream work).
   - **Target branch** — default to wherever this source branch's previous MRs went (agvic: stream MRs →
     `dev`, NOT `main`). Look it up: `gitlab-mr.sh recent <source>`. Else the project default branch.
   - **Title** — from the card title / commit subjects; imperative, ≤ 72 chars.
   - **Description** — draft from `git log --no-merges origin/<target>..<source>` (after step 2 this is only the stream's commits) and any Trello card,
     using the template below. Write it to `<scratchpad>/mr-description.md` and tell PJF the path so he can
     edit it in nvim if he prefers.
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
   Report the `!iid` and URL — one line — then offer the Teams post (see "Teams review request").

## MR description template

````markdown
## Summary
1–2 client-readable lines.

## Changes
- **<area / file>**: one line per change.

## Views changed
- `<asset>` (display | input | resource; mark NEW ones)

## Push
```bash
cd boards/<board>
weboard push "<resource>.js"     # resources first, then Util - Schema - *, then views
weboard push "<view>"
```
Tables / lists / groups: name them here as separate manual steps (not weboard).

## How to test
1. Position + incident, then numbered steps, each with the expected result. Keep it short.

## Out of scope        ← optional: what wasn't done, stated as fact
Card: <trello link>
````

Keep the `## How to test` heading exactly: `merge-and-deploy.sh` replays that section after it deploys.

**MRs are colleague-facing.** Call him **Patrick** (never "PJF"). Leave out conversation context: no "pending
Patrick's decision", "as discussed", "per our chat", or questions addressed to him. Saying something is out of
scope or wasn't implemented is fine — state it as a fact about the change. Same rule for `notify --note`.

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

New assets push fine by name (order: resources → `Util - Schema - *` views → other views). It also clears any
`delegate/test-push.sh` claims on the assets it pushed, warning if another stream's test build is overwritten. Still needs PJF's explicit go (the script lists
them as "needs PJF" and doesn't push them): `board-tables/` schema changes, `lists/` (webeoc-lists — destructive), and webeoc-groups changes
(`groups/*.json`, permission renames → re-grant; `push --overwrite` is non-atomic). Last, it prints the MR's
`## How to test` section. Report: merged sha, assets pushed, needs-PJF items, and those test steps (relay them
verbatim so PJF can re-test live).

Lower-level: `gitlab-mr.sh status <iid>` / `gitlab-mr.sh merge <iid>` / `gitlab-mr.sh description <iid> [--section <heading>]`.

## Pre-authorised mode (auto delegate streams)

When the stream's `STREAM-BRIEF.md` says it's an autonomous `/delegate --auto` stream, PJF has already
authorised the push + MR. Run steps 1, 2, 4, 5 without asking: push only `mr/<name>` (never the dev or
target branch), title from the card, description (template above, no chat context) to your session scratchpad `mr-description.md`
(never in the worktree), no draft, don't remove source. If `existing` finds an open MR for the pair,
push the updated branch and don't create a new one. If the brief has a `Teams: <channel>` line, run
`gitlab-mr.sh notify <iid> --channel <channel>` once the MR is new (not on an updated one). Any failure (no token, conflict, push rejected) → stop
and report to the orchestrator; don't work around it.

## Teams review request

After the MR is created, offer to post a review request card to Teams (outward-facing: the team sees it,
so ask unless pre-authorised):

```bash
gitlab-mr.sh notify <iid> [--channel code-reviews] [--note "<one-line ask>"] [--dry-run]
```

The card shows the MR title/link, repo, branches and author, plus a footer (`TEAMS_SIGNATURE` in the env file, e.g. "Pat's agent wrote this message").
Webhook: a Teams Workflows "Send webhook alerts to a channel" URL in `~/.config/teams/<channel>.env`
(`TEAMS_WEBHOOK_URL=...`, chmod 600); `code-reviews` is the only channel set up. Never paste the URL into
chat or a tracked file. Pre-authorised streams post only if their `STREAM-BRIEF.md` names a channel.
