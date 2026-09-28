# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository (`~/dotfiles`), used across macOS (personal) and WSL/Windows (work). The primary content is a **kickstart.nvim**-based Neovim configuration with custom modifications, plus shell, tmux, and Claude Code config.

## opencode

[opencode](https://opencode.ai) is set up to **coexist** with Claude Code (not replace it). It reuses the Claude config to avoid duplication:

- **Rules** — opencode falls back to `~/.claude/CLAUDE.md` (the user-level rules). No `~/.config/opencode/AGENTS.md` exists, on purpose, so that file stays the single source of truth.
- **Skills** — opencode reads `~/.claude/skills/*/SKILL.md` natively, so all custom skills load unchanged.
- **opencode-specific config** lives in `opencode/` and is symlinked to `~/.config/opencode/` by `install.sh`:
  - `opencode/opencode.json` — provider/model (OpenRouter) and permissions.
  - `opencode/tui.json` — theme (`tokyonight`, matching nvim) and TUI prefs.
- **Auth** is one-time and not committed: `opencode auth login` → OpenRouter.
- **Not ported:** Claude Code harness features with no opencode equivalent (voice, push notifications, Anthropic-shipped commands like `/code-review`, `/loop`), and the `claude/memory/` recall system (no native opencode equivalent — skipped for now).

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
