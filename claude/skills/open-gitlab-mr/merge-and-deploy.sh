#!/usr/bin/env bash
# merge-and-deploy.sh — the post-approval flow for a WebEOC board repo:
#   merge the MR on GitLab → fast-forward the local target branch → targeted `weboard push` of every
#   board asset the MR changed (one asset per call, from the board dir).
#
# Usage (run from the repo's MAIN checkout, on the MR's target branch):
#   merge-and-deploy.sh <iid> [--board-dir <dir>] [--dry-run]
#
#   --board-dir  board directory containing board-displays/ etc. (default: the only boards/*/ dir)
#   --dry-run    print what would be merged/pushed; change nothing
#
# Already-merged MRs skip the merge step. Stops (exit 1) without pushing when:
#   the tree has tracked changes, the MR isn't mergeable, the local branch can't fast-forward,
#   `weboard dev` is running, or any push doesn't report success.
# NOT pushed automatically (listed as "needs PJF"): new assets (need a full push), board-tables/ (schema),
# lists/ (webeoc-lists, destructive), and anything groups-related.
set -euo pipefail

die() { echo "merge-and-deploy: $*" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
gl="$here/gitlab-mr.sh"

iid="" board_dir="" dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --board-dir) board_dir="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    -*) die "unknown flag $1" ;;
    *) [ -z "$iid" ] || die "unexpected arg $1"; iid="$1"; shift ;;
  esac
done
[ -n "$iid" ] || die "MR iid required"

root=$(git rev-parse --show-toplevel)
[ "$(git rev-parse --path-format=absolute --git-common-dir)" = "$root/.git" ] || die "run from the main checkout"
cd "$root"
if [ -z "$board_dir" ]; then
  dirs=(boards/*/); [ ${#dirs[@]} -eq 1 ] && [ -d "${dirs[0]}" ] || die "pass --board-dir (found: ${dirs[*]})"
  board_dir=${dirs[0]%/}
fi
[ -d "$board_dir/board-displays" ] || die "$board_dir doesn't look like a board dir"

# 1. MR state → merge if needed
status=$("$gl" status "$iid")            # !39 opened mergeable conflicts=false src→tgt
echo "$status"
state=$(awk '{print $2}' <<<"$status"); merge_status=$(awk '{print $3}' <<<"$status")
target=$(awk '{print $5}' <<<"$status"); target=${target#*→}
[ "$(git branch --show-current)" = "$target" ] || die "check out '$target' in the main checkout first"
[ -z "$(git status --porcelain --untracked-files=no)" ] || die "tracked changes in the working tree — commit or stash first"
case "$state" in
  merged) echo "already merged" ;;
  opened)
    [ "$merge_status" = mergeable ] || die "MR !$iid is not mergeable ($merge_status)"
    if [ $dry -eq 1 ]; then echo "[dry-run] would merge !$iid"; else "$gl" merge "$iid"; fi ;;
  *) die "MR !$iid is $state" ;;
esac

# 2. fast-forward the local target branch
git fetch -q origin "$target"
if [ $dry -eq 0 ]; then
  git merge-base --is-ancestor "$target" "origin/$target" \
    || die "local $target has commits not on origin/$target — can't fast-forward; resolve by hand"
  git merge --ff-only -q "origin/$target"
  echo "$target → $(git log --oneline -1)"
fi

# 3. assets the MR changed (diff of its merge commit on the target branch)
mc=$(git log --format=%H --merges -1 --grep="See merge request .*!$iid\$" "origin/$target") \
  || true
[ -n "$mc" ] || die "can't find the merge commit for !$iid on origin/$target"
push=() manual=()
while IFS= read -r f; do
  rel=${f#"$board_dir"/}; [ "$rel" != "$f" ] || continue        # outside the board dir → not a platform asset
  kind=${rel%%/*}; rest=${rel#*/}; name=${rest%%/*}
  case "$kind" in
    board-displays|board-inputs|board-resources)
      if git cat-file -e "$mc^1:$board_dir/$kind/$name" 2>/dev/null; then push+=("$name")
      else manual+=("$name (NEW asset — needs a full weboard push)"); fi ;;
    board-tables) manual+=("$name (table schema change)") ;;
    lists) manual+=("$rel (board list — webeoc-lists push)") ;;
  esac
done < <(git diff --name-only "$mc^1" "$mc")
mapfile -t push < <(printf '%s\n' "${push[@]}" | sort -u | sed '/^$/d')

echo "push:   ${push[*]:-(none)}"
[ ${#manual[@]} -eq 0 ] || printf 'needs PJF: %s\n' "${manual[@]}"
[ $dry -eq 0 ] || exit 0
[ ${#push[@]} -gt 0 ] || exit 0

# 4. targeted pushes
ps -eo args | grep -qiE '^[^ ]*(node[^ ]* )?[^ ]*weboard[^ ]* dev( |$)' && die "weboard dev is running — not pushing"
cd "$board_dir"
for a in "${push[@]}"; do
  out=$(weboard push "$a") || { echo "$out"; die "push failed: $a"; }
  echo "$out" | grep -F "🟢" | grep -v "Logged out" || true
  echo "$out" | grep -qF "$a successfully pushed" || { echo "$out"; die "push of $a didn't report success"; }
done
echo "deployed !$iid: ${#push[@]} asset(s)"
