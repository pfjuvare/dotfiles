---
name: Obsidian vault access
description: How to read/write to the user's Obsidian vault (juvare-pkm) from any project
type: reference
---

The user's Obsidian vault — the single source of truth — lives on the **Windows** side and is synced by OneDrive:
- Real path: `/mnt/c/Users/patrick.fitzgerald/OneDrive - Juvare/Documents/juvare-pkm`
- Symlink (use this): `/home/patrickfitzgerald/obsidian-vault`

**There is no `~/pkm` in WSL, and there should never be one.** `~/pkm` is the macOS-only vault location; on this machine writing to `~/pkm/...` silently creates a stray local directory that OneDrive never syncs, so the note is effectively lost. If a `~/pkm` appears, move its contents into `~/obsidian-vault/` and remove it.

**Always use the symlink path with standard `Read`/`Write`/`Glob` tools** — NOT the `mcp__obsidian-vault__*` tools.

**Why:** The `@modelcontextprotocol/server-filesystem` MCP server implements the MCP roots protocol, which causes Claude Code to override the server's CLI-configured directory with the project CWD. This means the MCP tools are restricted to the project directory regardless of config. This is a known limitation as of 2026-03.

**Vault structure:**
- `01 projects/01 active/` — active project notes (one folder per project, hub note named `<project>.md`)
- `01 daily-notes/`, `02 weekly-notes/` — journals
- Root level has misc notes
- Primarily uses 'maps of content' notes rather than directory organisation, with nearly all notes in the `zettelkasten` directory. For instance the `clients` file has links to clients which then have links and backlinks to client-related notes ie project MOCs/notes. For instance the `DPIRD Resource Management` note is the top level project note for the Resource Management board for the DPIRD client. Please follow this convention and read/write links more than assuming directory structure matters.
