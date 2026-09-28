#!/bin/bash
# Sets up dotfiles and installs dependencies.
# Expects the repo to live at ~/dotfiles

set -e

DOTFILES="$HOME/dotfiles"

if [ ! -d "$DOTFILES" ]; then
  echo "Error: $DOTFILES does not exist. Clone the repo there first."
  exit 1
fi

# On macOS, ensure Homebrew is on PATH (common for Apple Silicon)
if [[ "$(uname)" == "Darwin" ]]; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# Detect package manager
if command -v brew &>/dev/null; then
  PKG_MANAGER="brew"
elif command -v pacman &>/dev/null; then
  PKG_MANAGER="pacman"
elif command -v apt &>/dev/null; then
  PKG_MANAGER="apt"
else
  PKG_MANAGER="unknown"
  echo "Warning: could not detect a supported package manager. Skipping installs."
fi

install_pkg() {
  local pkg=$1
  echo "Installing $pkg..."
  case "$PKG_MANAGER" in
    brew)   brew install "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    apt)    sudo apt-get install -y "$pkg" ;;
  esac
}

# Refresh the apt package index once before installing anything.
if [ "$PKG_MANAGER" = "apt" ]; then
  sudo apt-get update
fi

# Install zsh
if ! command -v zsh &>/dev/null; then
  install_pkg zsh
fi

# Install fzf
if ! command -v fzf &>/dev/null; then
  install_pkg fzf
fi

# Install jq (used by the bin/herdr-* helpers to read the herdr CLI's JSON)
if ! command -v jq &>/dev/null; then
  install_pkg jq
fi

# Install tmux
if ! command -v tmux &>/dev/null; then
  install_pkg tmux
fi

# Install TPM (Tmux Plugin Manager)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# Install curl (needed below to fetch Neovim)
if ! command -v curl &>/dev/null; then
  install_pkg curl
fi

# Install ripgrep (Telescope live_grep, todo-comments)
if ! command -v rg &>/dev/null; then
  install_pkg ripgrep
fi

# Install fd (Telescope file finding) — Debian/Ubuntu names the package
# "fd-find" and the binary "fdfind", which Telescope autodetects.
if ! command -v fd &>/dev/null && ! command -v fdfind &>/dev/null; then
  if [ "$PKG_MANAGER" = "apt" ]; then
    install_pkg fd-find
  else
    install_pkg fd
  fi
fi

# Install Node.js + npm (Mason installs some LSP servers via npm).
# Debian/Ubuntu ship nodejs without npm, so install npm explicitly there.
if ! command -v node &>/dev/null; then
  case "$PKG_MANAGER" in
    brew)   install_pkg node ;;
    pacman) sudo pacman -S --noconfirm nodejs npm ;;
    apt)    sudo apt-get install -y nodejs npm ;;
  esac
elif ! command -v npm &>/dev/null; then
  case "$PKG_MANAGER" in
    brew)   install_pkg node ;;
    pacman) sudo pacman -S --noconfirm npm ;;
    apt)    sudo apt-get install -y npm ;;
  esac
fi

# Install a C compiler toolchain (telescope-fzf-native + treesitter parsers).
if ! command -v cc &>/dev/null && ! command -v gcc &>/dev/null; then
  case "$PKG_MANAGER" in
    brew)   xcode-select --install 2>/dev/null || true ;;
    pacman) sudo pacman -S --noconfirm base-devel ;;
    apt)    sudo apt-get install -y build-essential ;;
  esac
fi

# Install / upgrade Neovim — the nvim config requires >= 0.11. Distro repos
# (apt/pacman) often ship an older Neovim, so on Linux we install the official
# static build into ~/.local instead of using the package manager.
NVIM_VERSION="v0.12.2"
nvim_recent_enough() {
  command -v nvim &>/dev/null || return 1
  local v
  v=$(nvim --version | head -1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+).*/\1/')
  [ "$(printf '%s\n0.11\n' "$v" | sort -V | head -1)" = "0.11" ]
}
if nvim_recent_enough; then
  echo "Neovim $(nvim --version | head -1 | awk '{print $2}') already installed."
elif [ "$PKG_MANAGER" = "brew" ]; then
  install_pkg neovim
else
  case "$(uname -m)" in
    x86_64|amd64)  nvim_arch="x86_64" ;;
    aarch64|arm64) nvim_arch="arm64" ;;
    *)             nvim_arch="" ;;
  esac
  if [ -z "$nvim_arch" ]; then
    echo "Warning: unsupported arch $(uname -m); install Neovim >= 0.11 manually."
  else
    echo "Installing Neovim $NVIM_VERSION to ~/.local..."
    nvim_tar="nvim-linux-${nvim_arch}.tar.gz"
    nvim_tmp=$(mktemp -d)
    curl -fsSL -o "$nvim_tmp/$nvim_tar" \
      "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${nvim_tar}"
    rm -rf "$HOME/.local/nvim-linux-${nvim_arch}"
    mkdir -p "$HOME/.local/bin"
    tar -xzf "$nvim_tmp/$nvim_tar" -C "$HOME/.local"
    ln -sfn "$HOME/.local/nvim-linux-${nvim_arch}/bin/nvim" "$HOME/.local/bin/nvim"
    rm -rf "$nvim_tmp"
    echo "Installed Neovim to ~/.local/bin/nvim (ensure ~/.local/bin is on PATH)."
  fi
fi

# Install clipboard tool (needed for tmux/neovim clipboard integration on Linux/WSL)
if [[ "$(uname)" == "Linux" ]] && ! command -v xclip &>/dev/null; then
  install_pkg xclip
fi

# Install opencode (terminal AI coding agent; coexists with Claude Code).
# Official installer drops the binary in ~/.opencode/bin.
if ! command -v opencode &>/dev/null && [ ! -x "$HOME/.opencode/bin/opencode" ]; then
  echo "Installing opencode..."
  curl -fsSL https://opencode.ai/install | bash
fi

# Install herdr (terminal workspace manager for AI coding agents; coexists with
# tmux -- see herdr/config.toml for the keybindings ported from tmux.conf).
if ! command -v herdr &>/dev/null; then
  if [ "$PKG_MANAGER" = "brew" ]; then
    install_pkg herdr
  elif [[ "$(uname)" == "Linux" ]]; then
    # Direct release binary rather than `curl -fsSL https://herdr.dev/install.sh | sh`
    # (the documented install): the work proxy blocks .sh downloads.
    case "$(uname -m)" in
      x86_64 | amd64) herdr_arch="x86_64" ;;
      aarch64 | arm64) herdr_arch="aarch64" ;;
      *) herdr_arch="" ;;
    esac
    if [ -n "$herdr_arch" ]; then
      echo "Installing herdr..."
      mkdir -p "$HOME/.local/bin"
      curl -fsSL -o "$HOME/.local/bin/herdr" \
        "https://github.com/herdrdev/herdr/releases/latest/download/herdr-linux-${herdr_arch}"
      chmod +x "$HOME/.local/bin/herdr"
      echo "Installed herdr to ~/.local/bin/herdr (ensure ~/.local/bin is on PATH)."
    else
      echo "Warning: no herdr release binary for $(uname -m); skipping."
    fi
  fi
fi

# Install zsh-syntax-highlighting
if [ "$PKG_MANAGER" = "brew" ]; then
  brew list zsh-syntax-highlighting &>/dev/null || brew install zsh-syntax-highlighting
elif [ "$PKG_MANAGER" = "pacman" ]; then
  pacman -Q zsh-syntax-highlighting &>/dev/null || sudo pacman -S --noconfirm zsh-syntax-highlighting
elif [ "$PKG_MANAGER" = "apt" ]; then
  dpkg -l zsh-syntax-highlighting &>/dev/null || sudo apt-get install -y zsh-syntax-highlighting
fi

# Set zsh as default shell
ZSH_PATH=$(command -v zsh)
if [ "$SHELL" != "$ZSH_PATH" ]; then
  echo "Setting default shell to zsh..."
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
  fi
  chsh -s "$ZSH_PATH"
fi

# Symlinks
echo "Creating symlinks..."

if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
  echo "Backing up existing .zshrc to .zshrc.bak"
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
ln -sf "$DOTFILES/zshrc" "$HOME/.zshrc"

mkdir -p "$HOME/.config"

if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
  echo "Backing up existing nvim config to ~/.config/nvim.bak"
  mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%s)"
fi
ln -sfn "$DOTFILES/nvim" "$HOME/.config/nvim"

if [ -d "$HOME/.config/tmux" ] && [ ! -L "$HOME/.config/tmux" ]; then
  echo "Backing up existing tmux config to ~/.config/tmux.bak"
  mv "$HOME/.config/tmux" "$HOME/.config/tmux.bak.$(date +%s)"
fi
ln -sfn "$DOTFILES/tmux" "$HOME/.config/tmux"

# Claude Code config
mkdir -p "$HOME/.claude"
ln -sf "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
if [[ "$(uname)" == "Darwin" ]]; then
  CLAUDE_PROJECT_DIR="$HOME/.claude/projects/-Users-$(whoami)"
else
  CLAUDE_PROJECT_DIR="$HOME/.claude/projects/-home-$(whoami)"
fi
mkdir -p "$CLAUDE_PROJECT_DIR"
ln -sfn "$DOTFILES/claude/memory" "$CLAUDE_PROJECT_DIR/memory"
ln -sfn "$DOTFILES/claude/skills" "$HOME/.claude/skills"
ln -sfn "$DOTFILES/claude/hooks" "$HOME/.claude/hooks"

# opencode config (coexists with Claude Code).
# Reuses ~/.claude/CLAUDE.md (rules) and ~/.claude/skills/*/SKILL.md (skills) via
# opencode's built-in fallback, so only the opencode-specific config lives here.
# One-time, not symlinked: run `opencode auth login` and pick OpenRouter.
mkdir -p "$HOME/.config/opencode"
ln -sf "$DOTFILES/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
ln -sf "$DOTFILES/opencode/tui.json" "$HOME/.config/opencode/tui.json"

# herdr config (keybindings ported from tmux -- see herdr/config.toml).
# Symlink the FILE, not the directory: herdr also keeps its sockets, logs, and
# session state in ~/.config/herdr, none of which belongs in this repo.
mkdir -p "$HOME/.config/herdr"
if [ -f "$HOME/.config/herdr/config.toml" ] && [ ! -L "$HOME/.config/herdr/config.toml" ]; then
  echo "Backing up existing herdr config to ~/.config/herdr/config.toml.bak"
  mv "$HOME/.config/herdr/config.toml" "$HOME/.config/herdr/config.toml.bak.$(date +%s)"
fi
ln -sf "$DOTFILES/herdr/config.toml" "$HOME/.config/herdr/config.toml"

# herdr's Claude Code integration: a SessionStart hook that reports agent state
# (idle / working / blocked / done) so herdr's sidebar tracks Claude accurately.
# It writes ~/.claude/hooks/herdr-agent-state.sh and the hook entry in
# ~/.claude/settings.json -- both symlinked into this repo, so the change lands
# here as a tracked diff. Installed only when missing, to avoid rewriting
# settings.json on every run.
if command -v herdr &>/dev/null; then
  if ! herdr integration status 2>/dev/null | grep -q '^claude: current'; then
    herdr integration install claude
  fi
fi

echo ""
echo "Done! Open a new terminal to start using zsh."
