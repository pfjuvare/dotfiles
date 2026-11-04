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
- **Self-test what I build before PJF sees it.** For every feature or fix to a tool or workflow I build for him (skills' scripts, `webeoc-guide`, agent-kit, CLIs), test it myself first. Where the repo has an automated suite (`webeoc-guide`: `npm test`), add a test for the new behaviour or the bug (reproduce it failing first) and run the **whole** suite before committing, so a fix can't silently break something earlier. Throwaway scratch checks don't count as the test: they miss regressions. For UI, drive it in headless Chromium the way he would (type, wait through background refreshes, click), not just the happy path. If something can't be tested here (a real Edge picker, a Windows-only path), say so explicitly when reporting.
- Prefer editing existing files over creating new ones.
- Use Homebrew for package management on macOS.
- Do not add Co-Authored-By lines to git commits.
- **Keep docs in sync with the change that triggered them.** When modifying a documented system or tool (Obsidian notes, CLAUDE.md files, READMEs, in-tool `--help` / usage text, memory files), update the relevant docs as part of the same change — don't defer to "later". Find every doc that references the thing you changed by searching for the feature/command/path/symbol name across likely locations (project docs, user-level CLAUDE.md, vault zettelkasten, memory dir). Skip only when the change is purely internal (refactor, dead-code removal, comment edits) and a doc reader wouldn't notice. If the doc surface to update is large or ambiguous, flag it and ask before sprawling.
  - **agent-kit overview (`~/code/agent-kit/docs/overview.html`) is a curated, concise doc.** After any change to the Streams / agent-kit workflow (skills, scripts, `webeoc-guide`, orchestration behaviour), decide whether a reader of that overview would notice. Obviously yes (new user-facing step, button, mode, rule) → make a concise edit yourself, in the same change. Borderline → ask PJF first, proposing the one-line wording; he wants it kept as short as possible. Internal-only → skip. Mirror edits into his personal copy `~/.claude/session-orchestrator/system-overview.html` (it keeps real client names).
- **End-of-turn summaries: restate each question/task with its answer.** When PJF's prompt contains multiple questions or tasks (typically a bulleted or dashed list), the end-of-turn summary should briefly restate each item alongside what I did/answered. This means he can read the summary top-to-bottom without scrolling back to re-load the question context. One terse line per item is enough — keep prose minimal, but make the restatement explicit. Format: short paraphrase of the question/task in bold (or as the lead clause), then the answer/result on the same line or immediately below. For single-task prompts, the existing concise direct summary is fine — don't manufacture restatement when there's only one thing. See `<vault>/zettelkasten/claude - end-of-turn summary format.md` for the rationale and worked example.

## Obsidian vault

- **Source of truth is the Windows-side vault**, synced by OneDrive:
  `/mnt/c/Users/patrick.fitzgerald/OneDrive - Juvare/Documents/juvare-pkm`
- **Access it from WSL via the symlink `~/obsidian-vault`** — use that path with `Read`/`Write`/`Glob`. There is deliberately **no `~/pkm` directory in WSL**; if one appears, it is a mistake (something wrote to a non-existent path and created it) — move the contents into the vault and remove it. On macOS only, the vault is the local `~/pkm`.
- Existing top-level folders: `01 projects` (containing `01 active`), `zettelkasten`, `reference`, `01 daily-notes`, `02 weekly-notes`, `daily notes`, `meetings`, `people`, `attachments`.
- **Default location for new notes**: the vault root (`~/obsidian-vault/`), unless the note belongs to a specific project — in which case place it inside that project's folder at `~/obsidian-vault/01 projects/01 active/<project>/`.
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

- Push a single list: `webeoc-lists push lists/<Name>.json --overwrite --url "$WE_URL" --username "$WE_USER" --password "$WE_PASSWORD"` (source `.env` first). `--overwrite` is **required** to update an existing list — it deletes + recreates the items; without it an already-existing list is skipped and your new item won't land. Because rest.svc only exposes `name`/`color` per item, an overwrite also **resets item icons, order and apply-permissions** (product source: `BoardListItemMgr.cs` SaveTree) — flag this if a list uses icons or per-group items.
- `--url` is the **base `WE_URL`** from `.env` (e.g. `https://host/board`), NOT `.../api/rest.svc` — despite what `--help` shows. See the `webeoc-lists-base-url` memory.
- **GOTCHA: a bare `webeoc-lists pull` downloads _every_ list on the server into `lists/`** — ~100 untracked files, and it overwrites/reformats the handful of tracked ones. To verify a single pushed list, pull into a throwaway scratch dir (or just trust the push output + `webeoc-lists ls`), never a bare pull in the repo. If it happens: `git checkout -- lists/<tracked files>` then `git clean -fd lists/`.
- Same caution as `weboard push`: it's a live mutation on the shared platform — ask / confirm `weboard dev` isn't running first.

### Groups — `groups/` folder is the source of truth (`webeoc-groups`)

Every client repo keeps its platform groups as `groups/<Group>.json` at the **repo root**, managed with the `webeoc-groups` CLI (`~/code/webeoc-groups`; if `webeoc-groups` isn't on PATH under the current nvm node, run `node ~/code/webeoc-groups/bin/webeoc-groups.js`).

- **Seed / refresh**: run `webeoc-groups pull --output <scratch dir>` from the repo root (where `.env` lives), then copy ONLY this board's groups into `groups/`. Same gotcha as lists: a bare pull fetches every group on the shared instance (~70 on agvic's).
- **Push** (`webeoc-groups push groups/<file> --overwrite --boards-dir boards`) is a live mutation — ask first, same as `weboard push`. `--overwrite` is NOT atomic: one rejected tag leaves the group with zero boards. Canary one group, then verify with a scratch-dir pull. Push uses `POST /groups/{g}` (full replace): a group file **missing `organizational`/`comments` resets them** to false/null on the server.
- **Validation gotcha**: tag validation keys on the board export **directory name** (e.g. `agvic-ops`), but group files name the **platform board** (`AgVic Operations`), so push validation is silently skipped. Until the tool maps the two, check tags by hand against `webeoc-groups permissions --boards-dir boards`.
- `test-push` / `merge-and-deploy` list `groups/*.json` changes as "needs PJF" and never push them.
- **Drift check**: before and after any groups change, compare the env's live groups with the branch
  (`webeoc-groups diff --dir groups --group-name <g>`, tag-order-insensitive; `--ignore-server-only` compares the whole
  `groups/` dir without the shared instance's other groups; exit 1 = drift, 2 = couldn't compare; `--json` available).
  Any difference is **flagged to PJF**,
  never resolved by assuming which side is right. Never push a group file without a fresh compare first.

### WebEOC date format — body locale attributes pattern

For dd/mm/yyyy display in MDB datepicker (and all date-aware widgets) without breaking save round-trips:

- Set the platform locale at the **`<body>` level**, NOT per-field via `data-mdb-format`.
- `data-mdb-format="dd/mm/yyyy"` on individual datepicker wrappers causes a parser mismatch — MDB displays in dd/mm/yyyy but WebEOC's underlying parser expects whatever the platform locale says, so saved dates get misinterpreted and corrupt records can result.
- Why (confirmed in product source): the posted string goes straight to SQL `dbo.convert2UTC` → `TRY_CAST` under the user's `SET DATEFORMAT` (ISO with `T` excepted); unparseable → **NULL, silently**. The `<body data-webeoc*>` attributes are read by the CXD libraries, not the platform; `/data` has no `@timezone` (hence the `@timezone` expression). See vault note `webeoc - dates are parsed by SQL SET DATEFORMAT and unparseable dates save as NULL`.

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

### WebEOC product source — check it when platform behaviour is unclear

We have **read-only (Reporter)** access to the WebEOC product repo: https://gitlab.juvare.com/webeoc/webeoc (default branch `develop`). Local shallow clone: **`~/code/webeoc-src`** (refresh: `git -C ~/code/webeoc-src pull --depth 1`; if missing: `git clone --depth 1 -b develop https://gitlab.juvare.com/webeoc/webeoc.git ~/code/webeoc-src`). Never commit/push to it.

- **Start at the vault MOC**: `~/obsidian-vault/zettelkasten/WebEOC source - map of content.md` — repo map, topic reference notes (`WebEOC source - *.md`: rendering pipeline, tag reference, expressions & SQL, save pipeline, client runtime, REST API, permissions/incidents/lists, changelog) and atomic gotcha notes (`webeoc - *.md`). Read the relevant note before guessing how a tag, save, filter, refresh or API call behaves.
- **If the notes don't cover it, inspecting the source is a first-class option** — prefer it over trial-and-error pushes to a live board, and over guessing a diagnosis. Entry points:
  - tag rendering → `WebEOC/Resources/admin/view.xsl`; column types → `admin_fieldlist.xsl`; view SQL → `sp.xsl`; save SQL → `save.xsl`
  - `/data` XML → `WebEOC/Shared/ESi.WebEOC.Library/ViewRenderer.cs`; data/save engine → `.../DataEntity/Data.cs`; form post → `WebEOC/WebApp/ESi.WebEOC.App/AppCode/Board.cs`
  - client JS → `WebEOC/WebApp/ESi.WebEOC.App/js/boardmanager.js`, `boardscript.js`
  - REST → `WebEOC/Modules/API/REST/.../REST/*.cs` → `WebEOC/Shared/ESi.WebEOC.Library/API/Operations/*.cs`
  - plain-English behaviour specs → `specs/*.md`; per-release changes → `ChangeLog/<ver>/`; tag → HTML examples → `WebEOC/Shared/ESi.WebEOC.BoardEngine.Tests/Specflow/`
  - Use an Explore subagent for broad sweeps; cite `file:line`.
- `WEOC.rnc` is IntelliSense only — `view.xsl` is the truth. The CXD/ViewBase/common-ui libraries are NOT in this repo.
- `develop` may be ahead of a client's instance — check `ChangeLog/` for the version a fix landed in before relying on it.
- **Write findings back**: a new non-obvious finding becomes an atomic `zettelkasten/webeoc - <finding>.md` note (source `file:line` + commit researched; mark verified-in-code vs inferred), linked from the MOC and its topic note.
- Front-of-mind gotchas (details in the notes): UI edit saves **blank every unposted text field** in the view (disabled inputs, hidden boardpermission fields, unchecked checkboxes, partial `BoardScript.EditRecord`) — REST/Public API updates are partial; `{…}` in view HTML attributes is evaluated as XPath (double braces for literals); `form.submit()` doesn't save (needs the `cmdSave` submitter); `deletebutton` only deletes incident-independent records; expressions outside the repeat ignore default view filters unless `useboardlevelfilters="true"`.

### Positions vs full administrator

A WebEOC *position* (what the user logs in as, e.g. AgVic Ops - Admin) and *full administrator* (a user-account flag) are different things. REST/API resolution defects usually hinge on full administrator vs a user-level account, not on the position. In test flows, guides, MRs and tickets, say which one you mean; don't write "non-admin positions" for an account-level difference.

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
