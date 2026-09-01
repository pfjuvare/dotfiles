# Homebrew (Apple Silicon)
if [[ "$(uname)" == "Darwin" ]] && [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# History
HISTSIZE=999999999
SAVEHIST=999999999
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt APPEND_HISTORY
# Write each command to $HISTFILE as it's entered, not at shell exit. Matters when
# a shell dies without a clean exit (tmux kill-pane, terminal window closed,
# SIGKILL) — with plain APPEND_HISTORY that session's commands can be lost.
setopt INC_APPEND_HISTORY

# Prompt: user@host:dir$ (matching bash theme colors)
autoload -U colors && colors
PROMPT='%B%F{green}%n@%m%f%b:%B%F{blue}%~%f%b$ '

# Set terminal title to user@host: dir
case "$TERM" in
xterm*|rxvt*)
    precmd() { print -Pn "\e]0;%n@%m: %~\a" }
    ;;
esac

# Color support
autoload -U compinit && compinit
if [[ "$(uname)" == "Darwin" ]]; then
  export CLICOLOR=1
  export LSCOLORS=GxFxCxDxBxegedabagaced
else
  eval "$(dircolors -b)"
  alias ls='ls --color=auto'
fi

# Grep
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ls
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Git
alias gst='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gco='git checkout'
alias gb='git branch'
alias gr='git remote'
alias gl='git log'
alias gd='git diff'

# Directory shortcuts (shared)
alias dotfiles='cd ~/dotfiles'

# Pull dotfiles changes from work machine and re-run install
dotpull() {
  cd ~/dotfiles || return
  git remote get-url work &>/dev/null || git remote add work git@github.com:pfjuvare/dotfiles.git
  git fetch work && git merge work/master && ./install.sh
}

# WSL-specific
if [[ -d /mnt/c ]]; then
  # Strip Windows Node.js from PATH
  export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v '/mnt/c/Program Files/nodejs' | tr '\n' ':' | sed 's/:$//')"
  # Corporate proxy CA certs
  export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

  # Work client directory shortcuts
  alias csg='cd ~/code/clients/CSG'
  alias ocrm='cd ~/code/clients/CSG/op-crm'
  alias dpird='cd ~/code/clients/DPIRD'
  alias dpirdrm='cd ~/code/clients/DPIRD/resource-management'
  alias dpirdpm='cd ~/code/clients/DPIRD/personnel-manager'
  alias ntfes='cd ~/code/clients/NTFES'
  alias qfd='cd ~/code/clients/QFD'
  alias qfpeople='cd ~/code/clients/QFD/boards/people'
  alias qflogistics='cd ~/code/clients/QFD/boards/logistics'
  alias qfwarnings='cd ~/code/clients/QFD/boards/warnings'
  alias sases='cd ~/code/clients/sa-ses'
  alias agvic='cd ~/code/clients/agvic'
  alias avops='cd ~/code/clients/agvic/boards/agvic-ops'
  alias watercorp='cd ~/code/clients/watercorp'
  alias wcdas='cd ~/code/clients/watercorp/boards/daily-awareness-system-rebuild/'
  alias wcww='cd ~/code/clients/watercorp/boards/waste-discharge-reporting-rebuild/'
  alias wcfaults='cd ~/code/clients/watercorp/boards/faults-register-rebuild/'
  alias pap='cd ~/code/clients/perth-airport/'

  # Juvare PKM (Obsidian vault on OneDrive)
  alias pkm='cd "/mnt/c/Users/patrick.fitzgerald/OneDrive - Juvare/Documents/juvare-pkm"'
fi

# macOS-specific
if [[ "$(uname)" == "Darwin" ]]; then
  # rbenv
  export PATH="${HOME}/.rbenv/bin:${PATH}"
  type -a rbenv > /dev/null 2>&1 && eval "$(rbenv init - zsh)"

  # Rails binstubs + node_modules binaries
  export PATH="./bin:./node_modules/.bin:${PATH}"

  # PostgreSQL (Homebrew)
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

  # Encoding
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8

  # Prevent Homebrew from reporting
  export HOMEBREW_NO_ANALYTICS=1
fi

# PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/dotfiles/bin:$PATH"

# Personal scripts (macOS)
if [[ "$(uname)" == "Darwin" ]] && [[ -d "$HOME/dev/scripts" ]]; then
  export PATH="$PATH:$HOME/dev/scripts"
fi

# FZF - show hidden files
export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/\.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# --- tmux dev layouts (ported from Omarchy / DHH, adapted for zsh) ---

# Attach to the most recent session, or start one
alias t='tmux attach || tmux new -s Work'

# IDE layout: editor left, agent right (30%), terminal bottom (15%)
# Usage: tdl <agent> [<second_agent>]   e.g. tdl claude, tdl claude opencode
tdl() {
  [[ -z $1 ]] && { echo "Usage: tdl <agent> [<second_agent>]"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tdl."; return 1; }

  local current_dir="$PWD"
  local editor_pane="$TMUX_PANE" ai_pane ai2_pane

  tmux rename-window -t "$editor_pane" "$(basename "$current_dir")"
  tmux split-window -v -l 15% -t "$editor_pane" -c "$current_dir"
  ai_pane=$(tmux split-window -h -l 30% -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')

  if [[ -n $2 ]]; then
    ai2_pane=$(tmux split-window -v -t "$ai_pane" -c "$current_dir" -P -F '#{pane_id}')
    tmux send-keys -t "$ai2_pane" "$2" C-m
  fi

  tmux send-keys -t "$ai_pane" "$1" C-m
  tmux send-keys -t "$editor_pane" "$EDITOR ." C-m
  tmux select-pane -t "$editor_pane"
}

# 2x2 square: editor / diff watch on top, terminal / agent below
# Usage: tds [agent]   (agent defaults to claude; DHH uses opencode + hunk)
tds() {
  [[ -z $TMUX ]] && { echo "You must start tmux to use tds."; return 1; }

  local current_dir="$PWD"
  local agent="${1:-claude}"
  local editor_pane="$TMUX_PANE" diff_pane terminal_pane agent_pane

  tmux rename-window -t "$editor_pane" "$(basename "$current_dir")"
  terminal_pane=$(tmux split-window -v -l 50% -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')
  diff_pane=$(tmux split-window -h -l 50% -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')
  agent_pane=$(tmux split-window -h -l 50% -t "$terminal_pane" -c "$current_dir" -P -F '#{pane_id}')

  tmux send-keys -t "$editor_pane" "$EDITOR ." C-m
  # DHH uses `hunk diff --watch` here; fall back to watch+git diff without it
  if command -v hunk &>/dev/null; then
    tmux send-keys -t "$diff_pane" "hunk diff --watch" C-m
  else
    tmux send-keys -t "$diff_pane" "watch --color -n 2 git diff --color=always" C-m
  fi
  tmux send-keys -t "$agent_pane" "$agent" C-m
  tmux select-pane -t "$editor_pane"
}

# One tdl window per subdirectory of the current directory
# Usage: tdlm <agent> [<second_agent>]
tdlm() {
  [[ -z $1 ]] && { echo "Usage: tdlm <agent> [<second_agent>]"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tdlm."; return 1; }

  setopt local_options null_glob
  local base_dir="$PWD"
  local first=true
  local dir dirpath pane_id

  # Session named after the directory (dots/colons are invalid in session names)
  tmux rename-session "$(basename "$base_dir" | tr '.:' '--')"

  for dir in "$base_dir"/*/; do
    [[ -d $dir ]] || continue
    dirpath="${dir%/}"

    if $first; then
      tmux send-keys -t "$TMUX_PANE" "cd '$dirpath' && tdl $1 $2" C-m
      first=false
    else
      pane_id=$(tmux new-window -c "$dirpath" -P -F '#{pane_id}')
      tmux send-keys -t "$pane_id" "tdl $1 $2" C-m
    fi
  done
}

# Swarm: tiled grid of N panes all running the same command
# Usage: tsl <pane_count> <command>   e.g. tsl 4 claude
tsl() {
  [[ -z $1 || -z $2 ]] && { echo "Usage: tsl <pane_count> <command>"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tsl."; return 1; }

  local count="$1" cmd="$2" current_dir="$PWD"
  local first_pane="$TMUX_PANE" new_pane pane
  local -a panes

  tmux rename-window -t "$first_pane" "$(basename "$current_dir")"
  panes=("$first_pane")

  while (( ${#panes[@]} < count )); do
    new_pane=$(tmux split-window -h -t "${panes[-1]}" -c "$current_dir" -P -F '#{pane_id}')
    panes+=("$new_pane")
    tmux select-layout -t "$first_pane" tiled
  done

  for pane in "${panes[@]}"; do
    tmux send-keys -t "$pane" "$cmd" C-m
  done

  tmux select-pane -t "$first_pane"
}

# Layout shortcuts (DHH's map: ic = editor+opencode, icx = editor+both agents)
alias ic='tdl claude'
alias icx='tdl claude opencode'

# Claude Code shortcuts
alias cy='claude --dangerously-skip-permissions'
alias cyc='claude -c --dangerously-skip-permissions'

# Private aliases (not tracked in git)
[ -f "$HOME/dotfiles/aliases.local" ] && source "$HOME/dotfiles/aliases.local"

# Vi mode
[ -f ~/.zsh/plugins/zsh-vi-mode/zsh-vi-mode.zsh ] && source ~/.zsh/plugins/zsh-vi-mode/zsh-vi-mode.zsh

# Syntax highlighting (must be last)
if [ -f "$(brew --prefix 2>/dev/null)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Default editor (used by opencode's editor_open, git, etc.)
export EDITOR=nvim
export VISUAL=nvim

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# railway
export PATH="$HOME/.railway/bin:$PATH"
