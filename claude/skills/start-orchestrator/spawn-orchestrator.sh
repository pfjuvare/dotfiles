#!/usr/bin/env bash
# spawn-orchestrator.sh — open (or re-lay-out) an orchestrator session: tmux window + Claude, from the
# repo's MAIN checkout. Same 3-column layout as delegate/spawn-stream.sh:
#   +---------+-------------------+---------+
#   |         |                   |  nvim   |
#   |  shell  |  claude (50%)     | scratch |
#   | (root)  |                   |         |
#   +---------+-------------------+---------+
#   Sides split the other 50% evenly. Target the claude pane by the id printed below, not by index.
#
# Usage:
#   spawn-orchestrator.sh [--name <window>] [--scratch <file>] [--session <tmux-session>]
#                         [--mode bypass|plan|default] [--prompt <text>]
#   spawn-orchestrator.sh --here [--scratch <file>]
#
#   --name     window name (default: <repo>-orchestrator).
#   --scratch  notes file opened in the right pane, relative to the main checkout
#              (default: orchestrator-scratch.md; created if missing, git-excluded via /*-scratch.md).
#   --session  tmux session (default: the current one).
#   --mode     bypass (default — streams message the orchestrator; any other mode queues them for
#              approval), plan, or default.
#   --prompt   first message (default: "/orchestrate" if the repo has .claude/skills/orchestrate,
#              else "/delegate").
#   --here     don't open a window: re-lay-out the CURRENT window around this pane ($TMUX_PANE) as the
#              claude column. Existing shell/nvim panes are reused; missing ones are created.
#   $SCRATCH_EDITOR  editor for the scratch pane (default nvim).
set -euo pipefail

die() { echo "spawn-orchestrator: $*" >&2; exit 1; }

name="" scratch="orchestrator-scratch.md" session="" mode="bypass" prompt="" here=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --scratch) scratch="$2"; shift 2 ;;
    --session) session="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    --prompt) prompt="$2"; shift 2 ;;
    --here) here=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) die "unknown arg $1" ;;
  esac
done

root=$(git rev-parse --show-toplevel)
common=$(git rev-parse --path-format=absolute --git-common-dir)
[ "$common" = "$root/.git" ] || die "run from the main checkout, not a worktree ($root)"
[[ "$prompt" != *"'"* ]] || die "--prompt must not contain single quotes"
[ -n "$prompt" ] || { [ -d "$root/.claude/skills/orchestrate" ] && prompt="/orchestrate" || prompt="/delegate"; }

exclude="$common/info/exclude"; mkdir -p "$(dirname "$exclude")"; touch "$exclude"
grep -qxF '/*-scratch.md' "$exclude" || echo '/*-scratch.md' >> "$exclude"
[ -e "$root/$scratch" ] || printf '# %s — orchestrator scratch\n\n' "$(basename "$root")" > "$root/$scratch"

# Arrange <shell> <claude> <scratch> left-to-right in window $1: claude 50%, sides even.
arrange() {
  local win=$1 shell=$2 claude=$3 note=$4 W C
  tmux select-layout -t "$win" even-horizontal
  # even-horizontal keeps pane order; put shell first, claude second, scratch third.
  local order; order=$(tmux list-panes -t "$win" -F '#{pane_id}' | tr '\n' ' ')
  set -- $order
  [ "$1" = "$shell" ] || { tmux swap-pane -d -s "$shell" -t "$1"; }
  order=$(tmux list-panes -t "$win" -F '#{pane_id}' | tr '\n' ' '); set -- $order
  [ "$2" = "$claude" ] || { tmux swap-pane -d -s "$claude" -t "$2"; }
  tmux select-layout -t "$win" even-horizontal
  W=$(tmux display -p -t "$win" '#{window_width}'); C=$((W / 2))
  tmux resize-pane -t "$shell" -x $(((W - C - 2) / 2))
  tmux resize-pane -t "$claude" -x "$C"
  tmux select-pane -t "$claude"
}

if [ $here -eq 1 ]; then
  [ -n "${TMUX_PANE:-}" ] || die "--here needs to run inside tmux"
  claude=$TMUX_PANE
  win=$(tmux display -p -t "$claude" '#{session_name}:#{window_index}')
  shell="" note=""
  while read -r id cmd; do
    [ "$id" = "$claude" ] && continue
    case "$cmd" in nvim|vim|"${SCRATCH_EDITOR:-nvim}") [ -z "$note" ] && note=$id ;; *) [ -z "$shell" ] && shell=$id ;; esac
  done < <(tmux list-panes -t "$win" -F '#{pane_id} #{pane_current_command}')
  [ "$(tmux list-panes -t "$win" | wc -l)" -le 3 ] || die "window has more than 3 panes; tidy it first"
  if [ -z "$note" ]; then
    note=$(tmux split-window -d -h -P -F '#{pane_id}' -t "$claude" -c "$root")
    sleep 0.5; tmux send-keys -t "$note" "${SCRATCH_EDITOR:-nvim} '$scratch'" Enter
  fi
  [ -n "$shell" ] || shell=$(tmux split-window -d -h -b -P -F '#{pane_id}' -t "$claude" -c "$root")
  arrange "$win" "$shell" "$claude" "$note"
  echo "window   $win re-laid out (claude $claude, shell $shell, scratch $note)"
  exit 0
fi

case "$mode" in
  plan) claude_cmd="claude --allow-dangerously-skip-permissions --permission-mode plan" ;;
  bypass) claude_cmd="claude --dangerously-skip-permissions" ;;
  default) claude_cmd="claude" ;;
  *) die "--mode must be bypass|plan|default" ;;
esac
[ -n "$name" ] || name="$(basename "$root")-orchestrator"
if [ -z "$session" ]; then
  [ -n "${TMUX:-}" ] || die "not inside tmux; pass --session"
  session=$(tmux display -p '#S')
fi
tmux has-session -t "$session" 2>/dev/null || die "tmux session '$session' not found"
tmux list-windows -t "$session" -F '#{window_name}' | grep -qx "$name" && die "window '$name' already exists in $session"

claude=$(tmux new-window -d -P -F '#{pane_id}' -t "$session:" -n "$name" -c "$root")
note=$(tmux split-window -d -h -l 25% -P -F '#{pane_id}' -t "$claude" -c "$root")
shell=$(tmux split-window -d -h -b -l 33% -P -F '#{pane_id}' -t "$claude" -c "$root")
sleep 0.5
tmux send-keys -t "$note" "${SCRATCH_EDITOR:-nvim} '$scratch'" Enter
tmux send-keys -t "$claude" "$claude_cmd '$prompt'" Enter
tmux select-pane -t "$claude"
echo "window   $session:$name  (claude pane $claude, shell $shell, scratch $note; mode $mode)"
echo "prompt   $prompt"
