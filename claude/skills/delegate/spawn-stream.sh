#!/usr/bin/env bash
# spawn-stream.sh — open a delegated work stream: git worktree + tmux window + Claude session.
#
# Layout of the new tmux window (named <name>-<desc>, or <name> without --desc):
#   +---------+-------------------+---------+
#   |         |                   |  nvim   |
#   |  shell  |  claude (50%)     | <name>- |
#   | (wt cwd)|                   | scratch |
#   +---------+-------------------+---------+
#   Sides split the other 50% evenly. Target the claude pane by the id printed below, not by index.
#
# Usage:
#   spawn-stream.sh <name> --brief <file> [--desc <slug>] [--base <branch>] [--session <tmux-session>]
#                   [--mode plan|bypass|default] [--prompt <text>] [--ui tmux|vscode]
#
#   <name>     stream id, e.g. uat-3sJx4mjm. Worktree: <repo>/.claude/worktrees/<name>,
#              branch: worktree-<name> (the `claude -w` convention).
#   --desc     tiny task tag appended to the tmux window name only, e.g. workshops ->
#              window uat-3sJx4mjm-workshops. 1-2 words, kebab-case, max 12 chars.
#   --brief    file copied to <worktree>/STREAM-BRIEF.md (the durable task brief). Required.
#   --base     branch to cut from (default: the main checkout's current branch).
#   --session  tmux session for the window (default: the current session).
#   --mode     plan (default): plan mode, bypass available via shift+tab / on plan approval.
#              bypass: start straight in bypass. default: normal permission prompts.
#   --prompt   first message (default: "Read STREAM-BRIEF.md in the worktree root and follow it.").
#   --ui       tmux (default, or $DELEGATE_UI): the window above. vscode: opens the worktree in a new
#              VS Code window and prints the claude command to run in its terminal.
#   $SCRATCH_EDITOR  editor for the scratch pane in tmux mode (default nvim).
#
# Run from anywhere inside the repo's MAIN checkout.
set -euo pipefail

die() { echo "spawn-stream: $*" >&2; exit 1; }

name="" desc="" brief="" base="" session="" mode="plan" ui=${DELEGATE_UI:-tmux}
prompt="Read STREAM-BRIEF.md in the worktree root and follow it."
while [ $# -gt 0 ]; do
  case "$1" in
    --brief) brief="$2"; shift 2 ;;
    --desc) desc="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --session) session="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    --prompt) prompt="$2"; shift 2 ;;
    --ui) ui="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    -*) die "unknown flag $1" ;;
    *) [ -z "$name" ] || die "unexpected arg $1"; name="$1"; shift ;;
  esac
done

[ -n "$name" ] || die "name required"
[[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "name must be [A-Za-z0-9._-]"
[ -z "$desc" ] || [[ "$desc" =~ ^[a-z0-9]+(-[a-z0-9]+)?$ && ${#desc} -le 12 ]] || die "--desc must be 1-2 kebab-case words, max 12 chars"
window="$name${desc:+-$desc}"
[ -n "$brief" ] && [ -f "$brief" ] || die "--brief <file> required"
[[ "$prompt" != *"'"* ]] || die "--prompt must not contain single quotes"
case "$ui" in tmux|vscode) ;; *) die "--ui must be tmux|vscode" ;; esac
[ "$ui" = tmux ] || command -v code >/dev/null || die "VS Code 'code' command not on PATH"

root=$(git rev-parse --show-toplevel)
common=$(git rev-parse --path-format=absolute --git-common-dir)
[ "$common" = "$root/.git" ] || die "run from the main checkout, not a worktree ($root)"
[ -n "$base" ] || base=$(git -C "$root" branch --show-current)
git -C "$root" rev-parse --verify -q "$base" >/dev/null || die "base branch '$base' not found"

if [ "$ui" = tmux ] && [ -z "$session" ]; then
  [ -n "${TMUX:-}" ] || die "not inside tmux; pass --session"
  session=$(tmux display -p '#S')
fi
if [ "$ui" = tmux ]; then
  tmux has-session -t "$session" 2>/dev/null || die "tmux session '$session' not found"
  tmux list-windows -t "$session" -F '#{window_name}' | grep -qx "$window" && die "window '$window' already exists in $session"
fi

wt="$root/.claude/worktrees/$name"
branch="worktree-$name"
[ -e "$wt" ] && die "worktree path exists: $wt"
git -C "$root" rev-parse --verify -q "$branch" >/dev/null && die "branch $branch already exists"

case "$mode" in
  plan) claude_cmd="claude --allow-dangerously-skip-permissions --permission-mode plan" ;;
  bypass) claude_cmd="claude --dangerously-skip-permissions" ;;
  default) claude_cmd="claude" ;;
  *) die "--mode must be plan|bypass|default" ;;
esac

# Keep the brief + scratch file out of git status in every worktree.
exclude="$common/info/exclude"
mkdir -p "$(dirname "$exclude")"; touch "$exclude"
for pat in 'STREAM-BRIEF.md' '/*-scratch.md'; do
  grep -qxF "$pat" "$exclude" || echo "$pat" >> "$exclude"
done

git -C "$root" worktree add -q "$wt" -b "$branch" "$base"
cp "$brief" "$wt/STREAM-BRIEF.md"
scratch="$wt/$name-scratch.md"
printf '# %s — scratch\n\n' "$name" > "$scratch"

if [ "$ui" = vscode ]; then
  code -n "$wt" "$scratch"
  echo "stream   $name"
  echo "worktree $wt"
  echo "branch   $branch (from $base @ $(git -C "$root" rev-parse --short "$base"))"
  echo "vscode   new window opened; in its terminal run:"
  echo "         $claude_cmd '$prompt'"
  exit 0
fi

claude=$(tmux new-window -d -P -F '#{pane_id}' -t "$session:" -n "$window" -c "$wt")
scratch_pane=$(tmux split-window -d -h -l 25% -P -F '#{pane_id}' -t "$claude" -c "$wt")   # right: 25%
shell=$(tmux split-window -d -h -b -l 33% -P -F '#{pane_id}' -t "$claude" -c "$wt")       # left: 1/3 of 75% = 25%
sleep 0.5 # let the shells initialise before typing into them
tmux send-keys -t "$scratch_pane" "${SCRATCH_EDITOR:-nvim} '$name-scratch.md'" Enter
tmux send-keys -t "$claude" "$claude_cmd '$prompt'" Enter
tmux select-pane -t "$claude"

echo "stream   $name"
echo "worktree $wt"
echo "branch   $branch (from $base @ $(git -C "$root" rev-parse --short "$base"))"
echo "window   $session:$window  (claude pane $claude, shell $shell, scratch $scratch_pane; mode $mode)"
