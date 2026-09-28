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

2. **Propose the fields**, pre-filled, in one short message and ask him to confirm or edit:
   - **Source branch** — default the current branch (or the finished stream's branch).
   - **Target branch** — default per project rules (agvic: `main` is MR-only, so `pf-dev` → `main`); else
     the project default branch from `check`.
   - **Title** — from the card title / commit subjects; imperative, ≤ 72 chars.
   - **Description** — draft from `git log --no-merges <target>..<source>` and any Trello card: summary,
     changes (one line per area), how to test, card link. Write it to
     `<scratchpad>/mr-description.md` and tell PJF the path so he can edit it in nvim if he prefers.
   - **Options** — draft? delete source branch on merge? (default: no / no).
   Also run `gitlab-mr.sh existing <source> <target>`; if an open MR already exists, show it and ask
   whether to stop instead.

3. **Source branch must be on the remote.** Check with `git ls-remote --heads origin <source>` and
   `git rev-list --count origin/<source>..<source>`. If it's missing or behind, **ask** before pushing —
   pushing is a separate confirmation from creating the MR. Respect project push rules (e.g. agvic's
   remote must be SSH).

4. **Dry run, then create** once PJF confirms:
   ```bash
   gitlab-mr.sh create --source <s> --target <t> --title "<title>" --description-file <f> [--draft] [--remove-source] --dry-run
   gitlab-mr.sh create --source <s> --target <t> --title "<title>" --description-file <f> [--draft] [--remove-source]
   ```
   Report the `!iid` and URL — one line.

## Not yet built

Posting a code-review request to Teams ("Pat's agent wrote this message") — deferred by PJF. Likely route:
a Teams incoming webhook / Workflows URL stored in `~/.config/teams/*.env`, called after step 4 with the
MR link. Outward-facing: confirm-first like the MR itself.
