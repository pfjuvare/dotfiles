#!/usr/bin/env bash
# spawn-session-orchestrator.sh — open the session orchestrator: its own tmux session with one window
# (named session-orch) in the stream layout, Claude in bypass on /session-orchestrator. It routes PJF's instructions to the repo
# orchestrators in the other tmux sessions (SendMessage), so he can drive them all from one place.
#   +---------+-------------------+---------+
#   |  shell  |  claude (50%)     |  nvim   |
#   |         |                   | scratch |
#   +---------+-------------------+---------+
#
# Usage:
#   spawn-session-orchestrator.sh [--session <name>] [--dir <path>] [--mode bypass|plan|default] [--no-switch]
#
#   --session    tmux session name (default: orch). Refuses if it already exists.
#   --dir        working directory for the panes (default: $HOME).
#   --mode       bypass (default — any other mode holds incoming SendMessages for approval), plan, default.
#   --no-switch  don't switch the current tmux client to the new session.
#   $SCRATCH_EDITOR  editor for the scratch pane (default nvim).
#
# Scratch + state live in ~/.claude/session-orchestrator/ (scratch.md, state.md).
set -euo pipefail

die() { echo "spawn-session-orchestrator: $*" >&2; exit 1; }

session="orch" dir="$HOME" mode="bypass" switch=1
while [ $# -gt 0 ]; do
  case "$1" in
    --session) session="$2"; shift 2 ;;
    --dir) dir="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    --no-switch) switch=0; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown arg $1" ;;
  esac
done

case "$mode" in
  plan) claude_cmd="claude --allow-dangerously-skip-permissions --permission-mode plan" ;;
  bypass) claude_cmd="claude --dangerously-skip-permissions" ;;
  default) claude_cmd="claude" ;;
  *) die "--mode must be bypass|plan|default" ;;
esac
[ -d "$dir" ] || die "dir not found: $dir"
tmux has-session -t "=$session" 2>/dev/null && die "tmux session '$session' already exists (tmux switch-client -t $session)"

home="$HOME/.claude/session-orchestrator"
mkdir -p "$home"
[ -e "$home/scratch.md" ] || printf '# session orchestrator — scratch\n\n' > "$home/scratch.md"
[ -e "$home/state.md" ] || printf '# session orchestrator — state\n\n' > "$home/state.md"

# Size the detached session like the current client so the percentage splits come out right.
size=()
[ -n "${TMUX:-}" ] && size=(-x "$(tmux display -p '#{window_width}')" -y "$(tmux display -p '#{window_height}')")
claude=$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -n session-orch -c "$dir" "${size[@]}")
note=$(tmux split-window -d -h -l 25% -P -F '#{pane_id}' -t "$claude" -c "$home")
shell=$(tmux split-window -d -h -b -l 33% -P -F '#{pane_id}' -t "$claude" -c "$dir")
sleep 0.5
tmux send-keys -t "$note" "${SCRATCH_EDITOR:-nvim} scratch.md" Enter
tmux send-keys -t "$claude" "$claude_cmd '/session-orchestrator'" Enter
tmux select-pane -t "$claude"

echo "session  $session  (claude pane $claude, shell $shell, scratch $note; mode $mode)"
echo "files    $home/{scratch,state}.md"
if [ $switch -eq 1 ] && [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$session"
else
  echo "attach   tmux switch-client -t $session   (or: tmux attach -t $session)"
fi
