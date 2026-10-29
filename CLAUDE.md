# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository (`~/dotfiles`), used across macOS (personal) and WSL/Windows (work). The primary content is a **kickstart.nvim**-based Neovim configuration with custom modifications, plus shell, tmux/herdr, and Claude Code config.

## opencode

[opencode](https://opencode.ai) is set up to **coexist** with Claude Code (not replace it). It reuses the Claude config to avoid duplication:

- **Rules** — opencode falls back to `~/.claude/CLAUDE.md` (the user-level rules). No `~/.config/opencode/AGENTS.md` exists, on purpose, so that file stays the single source of truth.
- **Skills** — opencode reads `~/.claude/skills/*/SKILL.md` natively, so all custom skills load unchanged.
- **opencode-specific config** lives in `opencode/` and is symlinked to `~/.config/opencode/` by `install.sh`:
  - `opencode/opencode.json` — provider/model (OpenRouter) and permissions.
  - `opencode/tui.json` — theme (`tokyonight`, matching nvim) and TUI prefs.
- **Auth** is one-time and not committed: `opencode auth login` → OpenRouter.
- **Not ported:** Claude Code harness features with no opencode equivalent (voice, push notifications, Anthropic-shipped commands like `/code-review`, `/loop`), and the `claude/memory/` recall system (no native opencode equivalent — skipped for now).

## herdr (tmux alternative)

[herdr](https://herdr.dev) is a terminal workspace manager built around AI coding
agents. It is installed **alongside** tmux, not as a replacement — both configs
are live and either can be used.

- `herdr/config.toml` — the config, symlinked to `~/.config/herdr/config.toml` by
  `install.sh`. Note it symlinks the **file**, not the directory: herdr keeps its
  sockets, logs, and session state in `~/.config/herdr` too.
- Keybindings are a deliberate port of `tmux/tmux.conf` (prefix `C-Space`, the
  same kill/split/jump/swap keys), so the muscle memory carries over. Every place
  the port is imperfect is commented inline in `config.toml`.
- Terminology: a tmux **window** is a herdr **tab**; a tmux **session** is a herdr
  **workspace**.
- `bin/herdr-pkm`, `bin/herdr-join-pane`, `bin/herdr-clone-tab` — the tmux binds
  with no native herdr action (`prefix + P`, `prefix + J`, `prefix + C` /
  `prefix + M-c`), wired up as `[[keys.command]]` entries. `herdr-clone-tab` talks
  to the socket API directly (`layout.export` / `layout.apply`) because the CLI has
  no layout subcommand.
- `claude/hooks/herdr-agent-state.sh` + the `SessionStart` hook in
  `claude/settings.json` are herdr's Claude Code integration (agent state in the
  sidebar), installed by `herdr integration install claude`. Both files are
  symlinked into this repo, so its edits land here as tracked diffs.
- **C-hjkl navigation**: under tmux, vim-tmux-navigator's tmux half checks whether
  the focused pane runs nvim and forwards the key. herdr has no conditional
  binding, so nvim drives it instead — `multiplexer_navigate` in `nvim/init.lua`
  moves within nvim's splits and calls `herdr pane focus` only at the edge. From a
  non-nvim pane, use `ctrl+alt+hjkl` or `prefix+hjkl`.
- **Not ported**: tmux's `send-prefix` (no literal `C-Space` passthrough, so nvim's
  blink.cmp `<C-space>` is unreachable inside herdr), `display-panes` /
  `M-!..M-(` indexed pane jumps, last-window / last-session, and the
  `tdl`/`tds`/`tdlm`/`tsl` dev-layout functions in `zshrc` plus `bin/tmux-*`
  (still tmux-only).
- Docs for agents: `https://herdr.dev/llms.txt` (index), `herdr --skill` (pane and
  agent control from inside a pane), `herdr config check` (validates
  `config.toml` and reports which binding wins a conflict).

## kanata (home row mods)

[kanata](https://github.com/jtroo/kanata) is a cross-platform keyboard remapper used to set up home row mods (tap a/s/d/f/j/k/l/; for letters, hold for Ctrl/Shift/Alt/Super — mirrored GACS layout).

- `kanata/kanata.kbd` — the config, symlinked to `~/.config/kanata/kanata.kbd` by `install.sh`.
- `kanata/kanata.service` — systemd user unit for Linux autostart, symlinked to `~/.config/systemd/user/`.
- `kanata/dev.kanata.kanata.plist` — macOS LaunchDaemon template (installed manually — see the plist's header comment).
- `install.sh` installs the kanata binary and wires up `/dev/uinput` access + the systemd service automatically on native Linux.
- **Skipped under WSL**: WSL2 has no access to the host's raw keyboard input, so kanata there can't intercept physical keys. Home row mods on a WSL machine require running kanata natively on the Windows host instead (not covered by this repo).
- **macOS requires manual steps**: installing the Karabiner-DriverKit-VirtualHIDDevice driver and approving it in System Settings can't be scripted — `install.sh` prints the steps instead of running them.

## Session orchestrator (optional top tier of Streams, the orchestrator system)

`claude/skills/session-orchestrator/` adds a tier above the per-repo orchestrators (`/start-orchestrator`,
`/delegate`): one Claude in its own tmux session (`orch`) that routes PJF's instructions to each session's
repo orchestrator via `SendMessage` and relays back questions, test flows and MR links. It never
implements, spawns streams, or does git/platform/tracker operations.

- Start: `/session-orchestrator` (renames its tmux window `session-orch`), or `claude/skills/session-orchestrator/spawn-session-orchestrator.sh`
  (`--session`, `--dir`, `--no-switch`). Opens in bypass so incoming messages aren't held.
- Discovery: tmux windows named `*orchestrator*`, matched to `ListAgents` rows by window id.
- State/scratch: `~/.claude/session-orchestrator/{state,scratch}.md`.
- Repo orchestrators handle `[session-orch]` messages per the delegate skill's "Session orchestrator" section.

## webeoc-guide (annotated test guides)

`~/code/webeoc-guide` is a separate repo (no remote yet, so it isn't a submodule here) that renders annotated, screen-by-screen HTML test guides for WebEOC views: spotlight highlights, arrows and numbered callouts. The **`test-guide` skill** (`claude/skills/test-guide/`) drives it, and `/delegate` streams use it at the test gate, linking the guide next to the text test flow.

- Run: `node ~/code/webeoc-guide/bin/webeoc-guide.js render <flow>.yaml [--uat] [--open]`. It writes `<flow>.html` (terse dev guide), or with `--uat` `<flow>.uat.html` (plain-English pass/fail version), and prints a `file://wsl.localhost/…` link that opens with ctrl+click in Windows Terminal. Flow format: its `README.md` and `examples/agvic-branch-input.yaml`.
- Screens are rendered **offline through the platform's own pipeline**: `admin_fieldlist.xsl` and `view.xsl` from `~/code/webeoc-src`, run on a sample `/data`. The board's JS runs against REST mocks from the flow. WebEOC hosts are never contacted, and the screens are not live screenshots. Without webeoc-src it falls back to a hand-written preview renderer.
- XSLT engine: `xsltproc` (`sudo apt-get install -y xsltproc`), else Python `lxml`, else Chromium's deprecated `XSLTProcessor`.
- Stream guide files (`/*-guide.*`) are git-excluded by `spawn-stream.sh`.
- **Feedback loop**: each guide has per-step feedback boxes (question / change / note) that "Save feedback to
  file" writes into the guide's HTML. `webeoc-guide feedback <guide>` lists open items, `respond` writes agent
  replies, `watch` blocks until the next save of new feedback; re-renders carry feedback over. The `guide-feedback` skill (`claude/skills/guide-feedback/`) works
  through it.
- Live-screenshot mode is parked because Imperva blocks tooling on agvic. See vault note `webeoc-guide - playwright annotated test guides (parked)`.
- `install.sh` installs its npm dependencies and Playwright Chromium (plus `libnss3 libnspr4 libasound2t64` on apt) when `~/code/webeoc-guide` exists without `node_modules`.

## Neovim Config Structure

The nvim config is based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) — a single-file starting point, not a distribution.

- `nvim/init.lua` — Main config file containing nearly all settings, keymaps, and plugin declarations. Custom additions are marked with `-- PJF:` comments.
- `nvim/lua/kickstart/plugins/` — Optional plugin modules (neo-tree is enabled; debug, indent_line, lint, autopairs, gitsigns are available but commented out in init.lua)
- `nvim/lua/custom/plugins/` — extra plugin specs, loaded via `{ import = 'custom.plugins' }` in init.lua: `init.lua` (vim-fugitive, ThePrimeagen/99) and `obsidian.lua`
- `nvim/lazy-lock.json` — Plugin lockfile (managed by lazy.nvim)

## Custom Modifications (PJF)

All custom changes in `init.lua` are marked with `-- PJF:` comments:

- `<leader>e` toggles Neo-tree file browser
- `<leader>y`/`<leader>p` mappings for system clipboard copy/paste
- `<leader>df` prompts for two file paths and opens them in codediff.nvim (`:CodeDiff file`)
- `NODE_EXTRA_CA_CERTS` environment variable set to work around corporate proxy SSL certificate issues
- GitHub Copilot plugin added (accepts suggestions with `<C-l>`, Tab is not mapped to avoid conflict with blink.cmp)
- LSP servers configured: `pyright`, `ts_ls`, `ruby_lsp`, `lua_ls`
- `vim-rails` plugin added

## Formatting

Lua files are formatted with **stylua**. Config is in `nvim/.stylua.toml`:
- 160 column width, 2-space indentation, single quotes preferred, no call parentheses

To check formatting: `stylua --check nvim/`
To format: `stylua nvim/`

## Key Settings

- Leader key: `<Space>`
- Nerd Font: disabled (`vim.g.have_nerd_font = false`)
- Colorscheme: `tokyonight-night` (italics disabled in comments)
- Plugin manager: lazy.nvim
- Completion: blink.cmp (default keymap preset, `<c-y>` to accept)
- Autoformat on save via conform.nvim (disabled for C/C++)
