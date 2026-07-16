--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = false

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- PJF: On WSL, force win32yank.exe — the WSLg X clipboard bridge is unreliable,
-- and nvim otherwise auto-picks xclip which doesn't sync to the Windows clipboard.
if vim.fn.has 'wsl' == 1 and vim.fn.executable 'win32yank.exe' == 1 then
  vim.g.clipboard = {
    name = 'win32yank-wsl',
    copy = {
      ['+'] = 'win32yank.exe -i --crlf',
      ['*'] = 'win32yank.exe -i --crlf',
    },
    paste = {
      ['+'] = 'win32yank.exe -o --lf',
      ['*'] = 'win32yank.exe -o --lf',
    },
    cache_enabled = 0,
  }
end

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- PJF: Treesitter-based folding (e.g. folds markdown by heading, nested).
-- Requires the relevant parser to be installed (:TSInstall <lang>).
-- foldlevelstart=99 keeps everything open on file open; zM to collapse.
vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- PJF: Use LF line endings instead of CRLF (WSL only — avoids issues editing files shared with Windows)
if vim.fn.has 'wsl' == 1 then
  vim.o.fileformat = 'unix'
  vim.o.fileformats = 'unix,dos'
end

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- PJF: Use 2 spaces instead of tabs for HTML/JS/JSON files.
-- JS/JSON included because conform's format_on_save has no JS formatter, so it
-- falls back to LSP (ts_ls) formatting, which retabs the file using expandtab.
-- Without this, saving board .js files converts all leading spaces to tabs.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'html', 'xhtml', 'javascript', 'json', 'typescript' },
  callback = function()
    vim.bo.tabstop = 2 --how many columns a \t character displays as (visual width of existing tabs)
    vim.bo.shiftwidth = 2 --how many columns to indent with >>, <<, and auto-indent
    vim.bo.softtabstop = 2 --how many columns the Tab key inserts (when combined with expandtab, it inserts spaces instead of a tab character)
    vim.bo.expandtab = true --pressing Tab inserts spaces instead of a literal \t character
  end,
})

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Split navigation with CTRL+<hjkl> is provided by vim-tmux-navigator (plugin
-- spec below): it moves between nvim splits and crosses seamlessly into adjacent
-- tmux panes. Replaces the manual <C-w>hjkl maps. See `:help wincmd`.

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- PJF: Custom keymaps
--
-- Center cursor after half-page scroll
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and center' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center' })

-- Center cursor after G (bottom of file)
-- vim.keymap.set('n', 'G', 'Gzz', { desc = 'Scroll to bottom and center' })
--
-- Set <leader>e to open neotree file browser
vim.keymap.set('n', '<leader>e', ':Neotree toggle<CR>', { desc = 'Toggle Neo-tree', noremap = true, silent = true })
--
--
-- PJF: Copy to system clipboard
vim.keymap.set('v', '<leader>y', '"+y')
vim.keymap.set('n', '<leader>Y', '"+yg_')
vim.keymap.set('n', '<leader>y', '"+y')
vim.keymap.set('n', '<leader>yy', '"+yy')

-- PJF: Paste from system clipboard
vim.keymap.set('n', '<leader>p', '"+p')
vim.keymap.set('n', '<leader>P', '"+P')
vim.keymap.set('v', '<leader>p', '"+p')
vim.keymap.set('v', '<leader>P', '"+P')

-- PJF: Show full file path
vim.keymap.set('n', '<leader>fp', function()
  vim.cmd 'echo expand("%:p")'
end, { desc = '[F]ile [P]ath' })

-- PJF: codediff.nvim - compare two files
vim.keymap.set('n', '<leader>df', function()
  vim.ui.input({ prompt = 'File A: ', completion = 'file' }, function(file_a)
    if not file_a or file_a == '' then
      return
    end
    vim.ui.input({ prompt = 'File B: ', completion = 'file' }, function(file_b)
      if not file_b or file_b == '' then
        return
      end
      vim.cmd('CodeDiff file ' .. vim.fn.fnameescape(file_a) .. ' ' .. vim.fn.fnameescape(file_b))
    end)
  end)
end, { desc = '[D]iff [F]iles' })

-- PJF: open the pkm vault in a NEW tmux window (named 'pkm', cwd ~/pkm, running
-- nvim on the vault). A new window beats a pane (cramped for a whole vault) or a
-- session (overkill) -- pkm gets full-screen space and `prefix + l` flips back.
vim.keymap.set('n', '<leader>oP', function()
  if vim.env.TMUX == nil then
    return vim.notify('Not inside tmux — cannot open a tmux window', vim.log.levels.WARN)
  end
  local pkm = vim.fn.expand '~/pkm'
  vim.fn.system { 'tmux', 'new-window', '-n', 'pkm', '-c', pkm, 'nvim', pkm }
end, { desc = 'Obsidian: open pkm vault in new tmux window' })

-- PJF: set NODE_EXTRA_CA_CERTS for npm-based tools (specifically github copilot in this case)
-- seemingly necessary to get around juvare's corporate proxy which intercepts SSL traffic and causes certificate errors for npm-based tools
-- “unable to get local issuer certificate” error
if vim.fn.has 'wsl' == 1 then
  vim.env.NODE_EXTRA_CA_CERTS = '/etc/ssl/certs/ca-certificates.crt'
end

-- PJF: Auto-reload files when modified externally (e.g. by Claude in another tmux pane)
vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  callback = function()
    vim.cmd 'checktime'
  end,
})

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- PJF: enable word wrap in Telescope preview windows
vim.api.nvim_create_autocmd('User', {
  pattern = 'TelescopePreviewerLoaded',
  callback = function()
    vim.wo.wrap = true
  end,
})

-- PJF: enable conceal only inside the pkm vault so obsidian.nvim's UI features
-- render there, without concealing in JSON/other filetypes across other projects.
-- conceallevel is window-local, so scope it by path and set it on every event that
-- shows a pkm note in a window (initial read, new split, tmux-resurrect-restored
-- windows) -- a markdown FileType autocmd alone misses splits and restored sessions.
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWinEnter' }, {
  pattern = vim.fn.expand '~/pkm' .. '/*.md',
  callback = function()
    vim.opt_local.conceallevel = 2
  end,
})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--

-- PJF: step to the previous/next day's daily note RELATIVE TO THE CURRENT NOTE.
-- The built-in :Obsidian yesterday/tomorrow are relative to the system date, so
-- they don't "cycle" when you're already viewing an older daily note. This parses
-- the date from the current buffer's filename (YYYY-MM-DD, or the legacy YYYYMMDD)
-- and opens the day +/- `delta` away; falls back to today if not on a daily note.
-- Used by <leader>o[ / <leader>o] in the obsidian.nvim spec below.
local function obsidian_daily_step(delta)
  local stem = vim.fn.expand '%:t:r'
  local y, m, d = stem:match '^(%d%d%d%d)%-(%d%d)%-(%d%d)$'
  if not y then
    y, m, d = stem:match '^(%d%d%d%d)(%d%d)(%d%d)$'
  end
  local anchor = y and os.time { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 } or os.time()
  require('obsidian.daily').daily({ date = anchor + delta * 24 * 3600 }):open()
end

-- PJF: weekly notes. obsidian.nvim has no native weekly/periodic-notes feature
-- (only daily_notes), so this is a small custom impl mirroring the daily flow
-- above. Notes live in ~/pkm/weekly notes/ named YYYY-MM-DD_weekly_note where the
-- date is the MONDAY of that week, so both Neovim and the desktop Periodic Notes
-- plugin open/create the same files on the synced vault (match its weekly format
-- 'YYYY-MM-DD_weekly_note' + folder 'weekly notes' to interoperate). No template.
local function obsidian_monday_of(t)
  -- Normalise to noon first so the whole-day subtraction below can't slip a day
  -- across a DST boundary.
  local parts = os.date('*t', t)
  parts.hour, parts.min, parts.sec = 12, 0, 0
  local noon = os.time(parts)
  local wday = os.date('*t', noon).wday -- 1=Sun .. 7=Sat
  local days_since_monday = (wday + 5) % 7 -- Mon(2)->0, Sun(1)->6
  return noon - days_since_monday * 24 * 3600
end

-- Open (or create) the weekly note for the week containing `datetime`.
local function obsidian_open_weekly(datetime)
  local Path = require 'obsidian.path'
  local Note = require 'obsidian.note'
  local monday = obsidian_monday_of(datetime)
  local id = os.date('%Y-%m-%d', monday) .. '_weekly_note'
  local path = Path.new(Obsidian.dir) / 'weekly notes' / (id .. '.md')
  local note
  if path:exists() then
    note = Note.from_file(path)
  else
    -- verbatim so the '_weekly_note' id isn't slugified; write() applies the
    -- vault's default frontmatter (same as a daily note), no body template.
    note = Note.create { id = id, verbatim = true, aliases = {}, tags = {}, dir = path:parent() }
    note:write()
  end
  note:open()
end

-- Used by <leader>o{ / <leader>o} to step weeks relative to the CURRENT note when
-- it's a weekly note, else relative to today (mirrors obsidian_daily_step).
local function obsidian_weekly_step(delta)
  local stem = vim.fn.expand '%:t:r'
  local y, m, d = stem:match '^(%d%d%d%d)%-(%d%d)%-(%d%d)_weekly_note$'
  local anchor = y and os.time { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 } or os.time()
  obsidian_open_weekly(anchor + delta * 7 * 24 * 3600)
end

-- PJF: <CR> wrapper for obsidian notes. The built-in checkbox cycle (smart_action
-- + checkbox.order = {' ','x',''}) goes [ ] -> [x] -> '- ' dash -> back to [ ], but
-- it can't REMOVE the list marker. This adds a 'no-dash / bare line' stop: on a
-- plain '- text' line it strips the '- ', so the full loop is
--   [ ] -> [x] -> '- ' dash -> bare line -> [ ]
-- (the bare -> [ ] step is the plugin's create_new, on by default). Everything
-- else -- links, headings, tags, and the rest of the cycle -- delegates to the
-- plugin's smart_action. Installed as a buffer-local <CR> map in the spec below.
local function obsidian_cr()
  local api = require 'obsidian.api'
  local line = vim.api.nvim_get_current_line()
  -- With checkbox.order = {'', ' ', 'x'} the plugin handles bare->'- ' dash->'[ ]'
  -- ->'[x]'. '- [x]' is the last state before looping back to a bare line, so we
  -- strip the WHOLE '- [x] ' prefix here. Guard with cursor_link/cursor_tag so
  -- pressing <CR> on a link/tag inside a '- [x] ...' item still follows it.
  local indent, body = line:match '^(%s*)%- %[x%]%s?(.*)$'
  if indent and not api.cursor_link() and not api.cursor_tag() then
    vim.api.nvim_set_current_line(indent .. body)
    return
  end
  -- otherwise defer to the plugin: smart_action returns keys to feed (noremap, so
  -- a returned literal '<CR>' runs the default action and never recurses into this)
  local keys = api.smart_action()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'n', false)
end

-- PJF: visual-mode counterpart to obsidian_cr. Applies the same short-cycle
-- checkbox toggle (bare -> '- ' dash -> [ ] -> [x] -> bare) to every line in
-- the visual selection instead of just the cursor line. The plugin's own
-- toggle_checkbox (used by <leader>oc) already loops over a visual range, but
-- like smart_action it can't remove the list marker -- it only cycles
-- '- [x]' back to a '- ' dash, not all the way to bare. So per line we check
-- for '- [x]' first and strip the whole prefix ourselves, same as
-- obsidian_cr, and otherwise fall back to the plugin's own per-line toggle
-- (actions._toggle_checkbox) for the bare/dash/[ ] steps.
--
-- Deliberately reads the range with line('v')/line('.') instead of
-- obsidian.api.get_visual_selection, which feedkeys an <Esc> and drops the
-- selection -- that made <CR> a one-shot action requiring reselection to
-- cycle again. Left untouched (no <Esc>, no cursor move), Neovim keeps the
-- visual selection active after the callback returns, so <CR> can be pressed
-- repeatedly to keep cycling the same lines through the states.
local function obsidian_cr_visual()
  local actions = require 'obsidian.actions'
  local start_lnum, end_lnum = vim.fn.line 'v', vim.fn.line '.'
  if start_lnum > end_lnum then
    start_lnum, end_lnum = end_lnum, start_lnum
  end
  local order = Obsidian.opts.checkbox.order
  for lnum = start_lnum, end_lnum do
    local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
    if line then
      local indent, body = line:match '^(%s*)%- %[x%]%s?(.*)$'
      if indent then
        vim.api.nvim_buf_set_lines(0, lnum - 1, lnum, true, { indent .. body })
      elseif line:match '%S' or Obsidian.opts.checkbox.create_new then
        actions._toggle_checkbox(order, lnum)
      end
    end
  end
end

-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically
  'https://github.com/tpope/vim-rails',

  -- PJF: highlight matching HTML/XML tags
  {
    'andymass/vim-matchup',
    event = 'BufReadPost',
    config = function()
      vim.g.matchup_matchparen_offscreen = { method = 'popup' }
    end,
  },

  -- PJF: codediff.nvim for improved git diffs
  {
    'esmuellert/codediff.nvim',
    cmd = 'CodeDiff',
    opts = {},
  },

  -- PJF: vim-tmux-navigator -- unified C-hjkl navigation across nvim splits and
  -- tmux panes (replaces the old manual <C-w>hjkl maps; tmux half is wired via TPM)
  {
    'christoomey/vim-tmux-navigator',
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
      'TmuxNavigatorProcessList',
    },
    keys = {
      { '<c-h>', '<cmd>TmuxNavigateLeft<cr>', desc = 'Navigate left (nvim split / tmux pane)' },
      { '<c-j>', '<cmd>TmuxNavigateDown<cr>', desc = 'Navigate down (nvim split / tmux pane)' },
      { '<c-k>', '<cmd>TmuxNavigateUp<cr>', desc = 'Navigate up (nvim split / tmux pane)' },
      { '<c-l>', '<cmd>TmuxNavigateRight<cr>', desc = 'Navigate right (nvim split / tmux pane)' },
      { '<c-\\>', '<cmd>TmuxNavigatePrevious<cr>', desc = 'Navigate to previous split/pane' },
    },
  },

  -- PJF: obsidian.nvim for editing an Obsidian vault from Neovim
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    ft = 'markdown',
    cmd = 'Obsidian',
    -- PJF: the plugin hardcodes its bullet-conceal to match '-', '*' AND '+'
    -- (ui.lua: `"^%s*[-%*%+] "`), with no config knob, so '*' and '+' list
    -- markers also render as '•'. Patch the marker class down to '-' only so '*'
    -- and '+' stay literal. Runs on install and re-applies after every :Lazy
    -- update (the git pull resets ui.lua, then build re-patches). A Lua function
    -- rather than a shell string: it's cross-platform, and lazy.nvim routes any
    -- build string ending in `.lua` to its "load a Lua file" branch instead of
    -- the shell. Idempotent — matches the upstream class `[-%*%+]` or a
    -- half-patched `[-%*]`.
    build = function(plugin)
      local path = plugin.dir .. '/lua/obsidian/ui.lua'
      local f = io.open(path, 'r')
      if not f then
        return
      end
      local content = f:read '*a'
      f:close()
      local patched = content:gsub('%[%-%%%*%%%+%]', '[-]'):gsub('%[%-%%%*%]', '[-]')
      if patched ~= content then
        local w = io.open(path, 'w')
        if w then
          w:write(patched)
          w:close()
        end
      end
    end,
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    keys = {
      -- open / find / create
      { '<leader>oo', '<cmd>Obsidian quick_switch<cr>', desc = 'Obsidian: open/switch note' },
      { '<leader>on', '<cmd>Obsidian new<cr>', desc = 'Obsidian: new note' },
      { '<leader>os', '<cmd>Obsidian search<cr>', desc = 'Obsidian: search (grep)' },
      { '<leader>og', '<cmd>Obsidian tags<cr>', desc = 'Obsidian: find by tag' },
      -- daily notes
      { '<leader>ot', '<cmd>Obsidian today<cr>', desc = 'Obsidian: today' },
      { '<leader>oy', '<cmd>Obsidian yesterday<cr>', desc = 'Obsidian: yesterday' },
      { '<leader>om', '<cmd>Obsidian tomorrow<cr>', desc = 'Obsidian: tomorrow' },
      { '<leader>od', '<cmd>Obsidian dailies<cr>', desc = 'Obsidian: browse dailies' },
      -- cycle daily notes relative to the CURRENT note (older/newer day)
      {
        '<leader>o[',
        function()
          obsidian_daily_step(-1)
        end,
        desc = 'Obsidian: previous day note',
      },
      {
        '<leader>o]',
        function()
          obsidian_daily_step(1)
        end,
        desc = 'Obsidian: next day note',
      },
      -- weekly notes (custom; see obsidian_open_weekly). Monday-anchored,
      -- ~/pkm/weekly notes/YYYY-MM-DD_weekly_note.md. Braces step weeks, paralleling
      -- the brackets that step days above.
      {
        '<leader>ow',
        function()
          obsidian_open_weekly(os.time())
        end,
        desc = 'Obsidian: this week',
      },
      {
        '<leader>o{',
        function()
          obsidian_weekly_step(-1)
        end,
        desc = 'Obsidian: previous week note',
      },
      {
        '<leader>o}',
        function()
          obsidian_weekly_step(1)
        end,
        desc = 'Obsidian: next week note',
      },
      -- navigation within / around a note
      { '<leader>ob', '<cmd>Obsidian backlinks<cr>', desc = 'Obsidian: backlinks' },
      { '<leader>ol', '<cmd>Obsidian links<cr>', desc = 'Obsidian: links in note' },
      { '<leader>ox', '<cmd>Obsidian toc<cr>', desc = 'Obsidian: table of contents' },
      -- follow the link under cursor into a split ('<CR>' follows in place)
      { '<leader>ov', '<cmd>Obsidian follow_link vsplit<cr>', desc = 'Obsidian: follow link in vsplit' },
      { '<leader>oh', '<cmd>Obsidian follow_link hsplit<cr>', desc = 'Obsidian: follow link in hsplit' },
      -- editing. <CR> (built-in smart action) cycles the SHORT set via
      -- checkbox.order below: dash -> [ ] -> [x]. <leader>oc cycles the FULL set
      -- of statuses by temporarily swapping in the longer order list.
      {
        '<leader>oc',
        function()
          local cfg = Obsidian.opts.checkbox
          local saved = cfg.order
          cfg.order = { ' ', 'x', '~', '!', '>', '' }
          pcall(require('obsidian.actions').toggle_checkbox)
          cfg.order = saved
        end,
        mode = { 'n', 'v' },
        desc = 'Obsidian: cycle all checkbox statuses',
      },
      { '<leader>oT', '<cmd>Obsidian template<cr>', desc = 'Obsidian: insert template' },
      { '<leader>oi', '<cmd>Obsidian paste_img<cr>', desc = 'Obsidian: paste image' },
      { '<leader>or', '<cmd>Obsidian rename<cr>', desc = 'Obsidian: rename + fix links' },
      -- visual-mode: extract / link a selection
      { '<leader>oe', '<cmd>Obsidian extract_note<cr>', mode = 'v', desc = 'Obsidian: extract selection to note' },
      { '<leader>ok', '<cmd>Obsidian link<cr>', mode = 'v', desc = 'Obsidian: link selection' },
    },
    opts = {
      legacy_commands = false,
      workspaces = {
        {
          name = 'pkm',
          path = '~/pkm',
        },
      },
      -- PJF: daily notes -> ~/pkm/daily notes/YYYY-MM-DD.md (:Obsidian today/etc).
      -- Existing history in that folder uses YYYYMMDD; new ones use YYYY-MM-DD.
      -- workdays_only defaults to true, which makes :Obsidian yesterday/tomorrow
      -- skip weekends (e.g. Monday's "yesterday" = Friday); set false for literal
      -- calendar days, matching <leader>o[ / <leader>o] which always step +/-1 day.
      daily_notes = {
        folder = 'daily notes',
        date_format = 'YYYY-MM-DD',
        workdays_only = false,
      },
      -- PJF: <CR> checkbox cycle (dash first). '' is the plain '- ' dash and is
      -- order[1], so a bare line becomes a dash before a checkbox. Combined with
      -- the obsidian_cr wrapper (strips '- [x]' back to a bare line), the full
      -- loop is: bare -> '- ' dash -> [ ] -> [x] -> bare. The full set of statuses
      -- is reachable via <leader>oc (see keys table above).
      checkbox = {
        order = { '', ' ', 'x' },
      },
      -- PJF: silence the spurious "conceallevel set to 0" warning. Our autocmd
      -- (above) sets conceallevel=2 for pkm files, but obsidian's BufEnter check
      -- can still fire transiently in a tmux-resurrect-restored window before it
      -- runs. The custom checkbox icons are applied post-setup (see config below)
      -- rather than via ui.checkboxes, which would warn about ordering on launch.
      ui = {
        ignore_conceal_warn = true,
      },
    },
    config = function(_, opts)
      require('obsidian').setup(opts)
      -- Plain-Unicode checkbox icons (render without a Nerd Font). Set here, after
      -- setup, so passing `ui.checkboxes` through setup() doesn't trigger the
      -- "ui.checkboxes no longer affects ordering" warning on every launch. The
      -- renderer reads Obsidian.opts.ui live, so these take effect. Colors
      -- (hl_group) and cycle order (checkbox.order) are left untouched.
      local cb = Obsidian.opts.ui.checkboxes
      cb[' '].char, cb['x'].char = '☐', '✓'
      cb['~'].char, cb['!'].char, cb['>'].char = '✗', '!', '→'

      -- PJF: fix ]o / [o link navigation. Upstream's Note:links() (via
      -- search.find_links) dedupes matches by link *text*, so the 2nd+ time a
      -- link string repeats in a buffer it's dropped from the nav list. Result:
      -- pressing ]o/[o on a line whose links all appear earlier (e.g. a summary
      -- line repeating [[TLS]]/[[DNS]]/[[caddy]]) skips right over them. We
      -- replace actions.nav_link (which api.nav_link, and thus ]o/[o, resolve to
      -- at call time) with a version that lists every link occurrence by
      -- position. Logic mirrors upstream otherwise: per-line find_refs with the
      -- same excludes, cursor set to {line, col} so it lands on the link itself.
      require('obsidian.actions').nav_link = function(direction)
        local search = require 'obsidian.search'
        local cursor_line, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
        local matches = {}
        for lnum, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          for _, ref in ipairs(search.find_refs(line, { exclude = { 'BlockID', 'Tag' } })) do
            matches[#matches + 1] = { line = lnum, start = ref[1] - 1 }
          end
        end
        if direction == 'next' then
          for i = 1, #matches do
            local m = matches[i]
            if (m.line > cursor_line) or (m.line == cursor_line and cursor_col < m.start) then
              return vim.api.nvim_win_set_cursor(0, { m.line, m.start })
            end
          end
        elseif direction == 'prev' then
          for i = #matches, 1, -1 do
            local m = matches[i]
            if (m.line < cursor_line) or (m.line == cursor_line and cursor_col > m.start) then
              return vim.api.nvim_win_set_cursor(0, { m.line, m.start })
            end
          end
        end
      end

      -- PJF: override <CR> in vault buffers with our wrapper (adds the strip-marker
      -- step; see obsidian_cr). The plugin re-maps <CR> on every BufEnter, so we
      -- re-assert ours via vim.schedule (runs after the plugin's handler) on each
      -- enter of a buffer the plugin has claimed (vim.b.obsidian_buffer).
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*.md',
        callback = function(ev)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) and vim.b[ev.buf].obsidian_buffer then
              vim.keymap.set('n', '<CR>', obsidian_cr, { buffer = ev.buf, desc = 'Obsidian smart action (+ strip-marker cycle)' })
              vim.keymap.set('v', '<CR>', obsidian_cr_visual, { buffer = ev.buf, desc = 'Obsidian: cycle checkbox status (visual)' })
            end
          end)
        end,
      })
    end,
  },

  -- NOTE: Plugins can also be added by using a table,
  -- with the first argument being the link and the following
  -- keys can be used to configure plugin behavior/loading/etc.
  --
  -- Use `opts = {}` to automatically pass options to a plugin's `setup()` function, forcing the plugin to be loaded.
  --

  -- Alternatively, use `config = function() ... end` for full control over the configuration.
  -- If you prefer to call `setup` explicitly, use:
  --    {
  --        'lewis6991/gitsigns.nvim',
  --        config = function()
  --            require('gitsigns').setup({
  --                -- Your gitsigns configuration here
  --            })
  --        end,
  --    }
  --
  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`.
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },
  -- PJF: start insertion
  -- PJF: added github copilot plugin for AI code suggestions
  {
    'github/copilot.vim',
    cmd = 'Copilot',
    event = 'InsertEnter',
    config = function()
      -- (optional) don’t steal <Tab> from nvim-cmp/snippets
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true

      -- Accept suggestion with Ctrl+f, (this doesn't overwrite the default nvim c-f mapping to scroll down a full page as it's only mapped in insert mode)
      vim.keymap.set('i', '<C-f>', 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
        silent = true,
        desc = 'Copilot accept',
      })
    end,
  },
  -- PJF: end insertion
  --
  --
  --
  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      -- this setting is independent of vim.o.timeoutlen
      delay = 0,
      icons = {
        -- set icon mappings to true if you have a Nerd Font
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>d', group = '[D]iff' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>o', group = '[O]bsidian', mode = { 'n', 'v' } },
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          layout_strategy = 'vertical',
          file_ignore_patterns = { '%.git/', 'node_modules/', '%.bak/' },
          -- PJF: make all Telescope searches case-insensitive
          vimgrep_arguments = {
            'rg',
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--smart-case',
            '--ignore-case',
            -- PJF: search hidden dotfiles too (.git/ still excluded via file_ignore_patterns)
            '--hidden',
          },
          -- mappings = {
          --   i = { ['<c-enter>'] = 'to_fuzzy_refine' },
          -- },
        },
        -- pickers = {}
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', function()
        -- PJF: explicit find_command so hidden+no-ignore work even when only rg is installed
        -- (telescope only translates these flags for fd, not rg)
        builtin.find_files {
          hidden = true,
          no_ignore = true,
          find_command = { 'rg', '--files', '--hidden', '--no-ignore', '--glob', '!.git/*' },
        }
      end, { desc = '[S]earch [F]iles' })
      -- PJF: search only HTML/XHTML files
      vim.keymap.set('n', '<leader>sx', function()
        builtin.find_files { prompt_title = 'Search XHTML/HTML Files', find_command = { 'find', '.', '-name', '*.xhtml', '-o', '-name', '*.html' } }
      end, { desc = '[S]earch [X]HTML/HTML files' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc. (PJF: as i've done here to make the window larger)
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
          layout_config = {
            width = 0.8,
            height = 0.6,
          },
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
    -- used for completion, annotations and signatures of Neovim apis
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- Find references for the word under your cursor.
          map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          --  Useful when your language has ways of declaring types without an actual implementation.
          map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the definition of the word under your cursor.
          --  This is where a variable was first declared, or where a function is defined, etc.
          --  To jump back, press <C-t>.
          map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Fuzzy find all the symbols in your current document.
          --  Symbols are things like variables, functions, types, etc.
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')

          -- Fuzzy find all the symbols in your current workspace.
          --  Similar to document symbols, except searches over your entire project.
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

          -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        -- clangd = {},
        -- gopls = {},
        pyright = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        ts_ls = {},
        --
        lua_ls = {
          -- cmd = { ... },
          -- filetypes = { ... },
          -- capabilities = {},
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      --
      -- `mason` had to be setup earlier: to configure its options see the
      -- `dependencies` table for `nvim-lspconfig` above.
      --
      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
        automatic_installation = false,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }
      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      -- vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- PJF: bamboo theme
  {
    'ribru17/bamboo.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('bamboo').setup {
        highlights = {
          ['@markup.link'] = { underline = false },
          ['@markup.link.label'] = { underline = false },
        },
      }
      vim.cmd 'silent colorscheme bamboo'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
  -- PJF: obsidian.nvim (community fork) lives in its own module, loaded just
  -- below via `require 'custom.plugins.obsidian'`. The old epwalsh/obsidian.nvim
  -- spec that used to sit here was the dead fork and has been removed.

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    -- PJF-cc: new nvim-treesitter only manages parser installation;
    -- highlighting/indentation are now built into Neovim.
    config = function()
      require('nvim-treesitter').setup {}
      -- PJF-cc: auto-install disabled because corporate proxy (Zscaler)
      -- blocks codeload.github.com. Run this manually on an unrestricted network:
      --   :TSInstall bash c diff html lua luadoc markdown markdown_inline query ruby vim vimdoc
    end,
  },

  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  require 'kickstart.plugins.neo-tree',
  -- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommend keymaps

  -- PJF: vim-tmux-navigator -- unified C-hjkl navigation across nvim splits and
  -- tmux panes (replaces the old manual <C-w>hjkl maps; tmux half is wired via TPM)
  {
    'christoomey/vim-tmux-navigator',
    cmd = {
      'TmuxNavigateLeft',
      'TmuxNavigateDown',
      'TmuxNavigateUp',
      'TmuxNavigateRight',
      'TmuxNavigatePrevious',
      'TmuxNavigatorProcessList',
    },
    keys = {
      { '<c-h>', '<cmd>TmuxNavigateLeft<cr>', mode = { 'n', 'i' }, desc = 'Navigate left (nvim split / tmux pane)' },
      { '<c-j>', '<cmd>TmuxNavigateDown<cr>', mode = { 'n', 'i' }, desc = 'Navigate down (nvim split / tmux pane)' },
      { '<c-k>', '<cmd>TmuxNavigateUp<cr>', mode = { 'n', 'i' }, desc = 'Navigate up (nvim split / tmux pane)' },
      { '<c-l>', '<cmd>TmuxNavigateRight<cr>', mode = { 'n', 'i' }, desc = 'Navigate right (nvim split / tmux pane)' },
      { '<c-\\>', '<cmd>TmuxNavigatePrevious<cr>', mode = { 'n', 'i' }, desc = 'Navigate to previous split/pane' },
    },
  },

  require 'custom.plugins.obsidian',

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  -- { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
