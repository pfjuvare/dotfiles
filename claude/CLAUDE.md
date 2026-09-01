# CLAUDE.md (User-level)

This file applies to all projects and provides global guidance to Claude Code.

## About Me

- I go by PJF
- ubuntu linux is my current primary development environment
- I also work in WSL and macOS (Apple Silicon) environments
- Editor: Neovim (kickstart.nvim-based config)
- Terminal multiplexer: tmux
- Shell: zsh
- Dotfiles repo: ~/dotfiles

## Preferences

- Be concise and direct. Don't over-explain. This is very important – it becomes very fatiguing reading overly verbose responses. I don't want to miss out on critical information from you overly cutting your responses short, but please be absolutely as concise as possible without withholding information.
- When making changes, keep working until the goal is fully achieved rather than stopping to ask for confirmation at every step.
- **Don't fix a reported problem on an assumed diagnosis — confirm the actual symptom first.** When PJF reports an issue, distinguish what he *observed* from my *theory of the cause*. If I can't directly observe the behaviour (e.g. platform/runtime state I can't see), confirm the real symptom — ask him what he sees, or verify directly — BEFORE implementing a fix. Building on a guessed root cause risks the wrong fix and wasted push/verify cycles. This does NOT contradict "keep working without confirming at every step": once the symptom/diagnosis is actually established (observed or verified), proceed without hand-holding. The gate is specifically on *unconfirmed diagnoses*, not on execution.
- When you discover issues or improvements during a task, fix them inline rather than just reporting them.
- **Merging a worktree branch into `main` is confidence-gated.** When work done in a git worktree is finished, decide whether to merge it into `main` based on confidence — a judgement call, not a hard rule. If the problem was well-defined and cleanly executed (clear scope, changes validate, no shaky trial-and-error), merge the worktree branch into `main` yourself without re-asking. If the work was challenging — debugging-heavy, platform behaviour I couldn't verify, a fix built on guesses, multiple uncertain attempts — ASK before merging and leave the commits sitting on the worktree branch. This is the local merge decision ONLY: it does not relax the "never `weboard push`/`pull` (or `webeoc-lists push`) without asking" rule. When in doubt about confidence, ask — the cost of asking is low.
- Prefer editing existing files over creating new ones.
- Use Homebrew for package management on macOS.
- Do not add Co-Authored-By lines to git commits.
- **Keep docs in sync with the change that triggered them.** When modifying a documented system or tool (Obsidian notes, CLAUDE.md files, READMEs, in-tool `--help` / usage text, memory files), update the relevant docs as part of the same change — don't defer to "later". Find every doc that references the thing you changed by searching for the feature/command/path/symbol name across likely locations (project docs, user-level CLAUDE.md, vault zettelkasten, memory dir). Skip only when the change is purely internal (refactor, dead-code removal, comment edits) and a doc reader wouldn't notice. If the doc surface to update is large or ambiguous, flag it and ask before sprawling.
- **End-of-turn summaries: restate each question/task with its answer.** When PJF's prompt contains multiple questions or tasks (typically a bulleted or dashed list), the end-of-turn summary should briefly restate each item alongside what I did/answered. This means he can read the summary top-to-bottom without scrolling back to re-load the question context. One terse line per item is enough — keep prose minimal, but make the restatement explicit. Format: short paraphrase of the question/task in bold (or as the lead clause), then the answer/result on the same line or immediately below. For single-task prompts, the existing concise direct summary is fine — don't manufacture restatement when there's only one thing. See `<vault>/zettelkasten/claude - end-of-turn summary format.md` for the rationale and worked example.

## Obsidian vault (`~/pkm`)

- PJF's Obsidian vault lives at `~/pkm`. Existing top-level folders: `01 projects` (with `01 active` / `02 inactive` / `03 ideas` / `04 archived`), `02 zettelkasten`, `03 reference`, `04 daily-notes`, `05 archive`, `07 leetcode`.
- **Default location for new notes**: the vault root (`~/pkm/`), unless the note belongs to a specific project — in which case place it inside that project's folder at `~/pkm/01 projects/01 active/<project>/`.
- Each active project has its own folder containing a hub note (`<project>.md`) plus any sub-notes. Within a project folder, prefix sub-notes with the project name (`<project> - <topic>.md`) to avoid wikilink collisions across the vault.
- Wikilinks in Obsidian resolve by filename, not path — so links like `[[pbudget]]` keep working regardless of folder location.

## Tools & Stack

- Package manager: Homebrew (Apple Silicon, /opt/homebrew)
- Node version manager: nvm
- Languages: Python, TypeScript, Ruby, Lua
- LSP servers: pyright, ts_ls, ruby_lsp, lua_ls

## WebEOC / weboard work — global rules

These apply to any client board project (CSG, DPIRD, NTFES, QFD, sa-ses, watercorp, AgVic, and any future ones).

### Never run `weboard push` or `weboard pull` without asking

`weboard dev` (file-watcher / live-sync) and `weboard push` / `weboard pull` use the same upload/download pipeline. Running them concurrently can race and corrupt state — local files overwritten by partial pushes, remote diverging from local, lost work.

- Before suggesting OR running `weboard push`, `weboard pull`, or anything that uses the same pipeline, **ask first**: "OK to run `weboard push <asset>` — is `weboard dev` running?" Wait for the green light.
- Same principle for `webeoc-lists push` (separate tool, same caution).
- If editing a per-view `config.json` (e.g. adding viewFilters), call out that the change won't take effect until pushed, and ASK rather than push silently.
- Exception: PJF himself running `weboard dev` is fine — that's his development loop. The problem is *me* triggering parallel platform operations.

### Pushing board lists — use `webeoc-lists`, not `weboard`

Board lists (the `lists/*.json` files) are pushed with the **`webeoc-lists`** CLI, NOT `weboard`. `weboard push <name>` treats lists as `board-lists/<Name>/` subdirectory assets, so on repos that keep lists as flat `lists/*.json` it fails with `Asset "<Name>" not found`, and `weboard push --overwrite-lists` only pushes lists as a side effect of a full/asset board push — which would also deploy unreviewed display/input changes live. Don't go down that path.

- Push a single list: `webeoc-lists push lists/<Name>.json --overwrite --url "$WE_URL" --username "$WE_USER" --password "$WE_PASSWORD"` (source `.env` first). `--overwrite` is **required** to update an existing list — it deletes + recreates the items; without it an already-existing list is skipped and your new item won't land.
- `--url` is the **base `WE_URL`** from `.env` (e.g. `https://host/board`), NOT `.../api/rest.svc` — despite what `--help` shows. See the `webeoc-lists-base-url` memory.
- **GOTCHA: a bare `webeoc-lists pull` downloads _every_ list on the server into `lists/`** — ~100 untracked files, and it overwrites/reformats the handful of tracked ones. To verify a single pushed list, pull into a throwaway scratch dir (or just trust the push output + `webeoc-lists ls`), never a bare pull in the repo. If it happens: `git checkout -- lists/<tracked files>` then `git clean -fd lists/`.
- Same caution as `weboard push`: it's a live mutation on the shared platform — ask / confirm `weboard dev` isn't running first.

### WebEOC date format — body locale attributes pattern

For dd/mm/yyyy display in MDB datepicker (and all date-aware widgets) without breaking save round-trips:

- Set the platform locale at the **`<body>` level**, NOT per-field via `data-mdb-format`.
- `data-mdb-format="dd/mm/yyyy"` on individual datepicker wrappers causes a parser mismatch — MDB displays in dd/mm/yyyy but WebEOC's underlying parser expects whatever the platform locale says, so saved dates get misinterpreted and corrupt records can result.

Required body-level wiring on every input view that has date fields:

```xml
<xsl:variable name="current_date" select="/data/@currentdate" />
<xsl:variable name="timezone">
  <expression name="exp_timezone">@timezone</expression>
</xsl:variable>
<xsl:variable name="is_return" select="/data/ViewParameter[@name='isReturn'] = 'true'" />
<body
  class="..."
  data-webeocdatetimeformat="{data/@webeocdatetimeformat}"
  data-webeocdateformat="{data/@webeocdateformat}"
  data-webeoctimezone="{$timezone}"
  data-webeocdaylight="{data/@daylight}"
  data-is-return="{$is_return}"
>
```

Then a normal `<div data-mdb-datepicker-init="true" data-mdb-input-init="true" data-mdb-inline="true">` wrapper with `<input type="text" fieldtype="datetime" />` — no `data-mdb-format` override.

PJF's `dates.md` Obsidian note (zettelkasten) covers related patterns: `<value-of select="date:formatdate(@field, /data/@webeocdatetimeformat)" />` for details views, SQL `FORMAT(dbo.convert2Local(...), 'dd/MM/yyyy')` expressions for explicit per-expression formatting.

### Multi-task batch reporting format

When PJF gives a list of TODOs to action in one batch:

- Per item: confirmation + a one-or-two-sentence change summary. Don't over-explain.
- Add a quick test flow only when the change is hard to verify from the diff (UI behaviour, runtime logic, navigation).
- Flag issues encountered while making changes — ambiguity in scope, blocking unknowns, things that needed a workaround.
- Never dump the diff or explain every line; PJF reads the diff himself.
- If a task is ambiguous, surface as a blocker and ask, OR pick a reasonable interpretation and explicitly flag the assumption.
- Always commit before reporting (so the diff lines up with what's described).

### Jira tickets — use the `pjc` CLI

When PJF references a Jira ticket by key (e.g. `FIMS-1235`, `PSAPAC-1453`), fetch it with `pjc` (Pat's Jira CLI — an instance-agnostic REST v2 wrapper at `~/.local/bin/pjc`) BEFORE reviewing. Don't rely on code comments or vault notes alone — they cite ACs but don't carry the discussion thread, and the actual "what's left to do" usually lives in the **newest comments**, which often supersede the original description/ACs.

**Pick the instance with a flag** — one config file per Jira, at `~/.config/jira/<instance>.env`. `--<instance>` works for any name with a matching env file. With no flag, the command runs against the default instance; precedence is `--<instance>` > `$PJC_ENV` > `~/.config/jira/default` (set via `pjc default <instance>`) > the sole instance if only one is configured. **Don't rely on the default — always pass the flag explicitly**, since it's user-settable and a wrong guess means querying the wrong organisation's Jira.

| Flag | Jira | Flavour | Project | Keys |
|---|---|---|---|---|
| `--qfd` | qfes.atlassian.net (client) | Cloud | FIMS | `FIMS-*` |
| `--juvare` | jira.juvare.com (internal) | Server/DC | PSAPAC | `PSAPAC-*` |

Infer the instance from the key prefix — `FIMS-*` → `--qfd`, `PSAPAC-*` → `--juvare`. `pjc envs` lists what's configured; `pjc --<instance> editenv` opens (or scaffolds) that instance's env file in nvim.

- `pjc --qfd issue <KEY>` → full issue details + comments (JSON). This is the source of truth for requirements and the latest product-owner direction; read the newest comments first, then compare against current code state.
- `pjc --qfd issues [jql]` → search (a bare word/phrase is wrapped as a status filter; anything with a JQL operator or `AND`/`OR`/`ORDER BY` passes through; default is `project = $JIRA_PROJECT ORDER BY updated DESC`). `pjc --qfd snapshot [outfile]` → markdown dump of the project's issues.
- `pjc --qfd raw <path> [k=v ...]` → raw GET against the v2 API for anything the subcommands don't cover.
- **Writes are outward-facing — ask first.** Create/update/comment/transition/assign are DISABLED unless `PJC_ALLOW_WRITES=1` (one-off prefix or persisted in the instance's env file). Treat any write as an outward-facing action and confirm with PJF first (same caution as `weboard push`). Auto-applies the instance's `JIRA_TOOL_LABEL` on issue-create unless `--no-tool-label`.
