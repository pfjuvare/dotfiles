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
# New assets push fine by name (needs their config.json sidecar). Order: board resources (so views re-sync
# against them — a view pushed before a new resource it references 403s), then `Util - Schema - *` views
# (new columns), then the rest. Clears ../delegate/test-push.sh claims on what it pushed (warns if another
# stream's test build gets overwritten).
# NOT pushed automatically (listed as "needs PJF"): board-tables/ (schema), lists/ (webeoc-lists, destructive),
# and groups/*.json at the repo root (webeoc-groups push — non-atomic) or any other groups change.
# Finally prints the MR description's "How to test" (or "Test steps") section for the live re-test.
set -euo pipefail

die() { echo "merge-and-deploy: $*" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
gl="$here/gitlab-mr.sh"

iid="" board_dir="" dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --board-dir) board_dir="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
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
if [ -n "$mc" ]; then base="$mc^1" head="$mc"
elif [ $dry -eq 1 ]; then                                   # not merged yet: preview from the MR's own diff
  src=$(awk '{print $5}' <<<"$status"); src=${src%→*}
  git fetch -q origin "$src"
  base=$(git merge-base "origin/$target" "origin/$src") head="origin/$src"
else die "can't find the merge commit for !$iid on origin/$target"; fi
push=() res=() schema=() manual=()
while IFS= read -r f; do
  case "$f" in groups/*.json) manual+=("$f (group — webeoc-groups push, non-atomic)"); continue ;; esac
  rel=${f#"$board_dir"/}; [ "$rel" != "$f" ] || continue        # outside the board dir → not a platform asset
  kind=${rel%%/*}; rest=${rel#*/}; name=${rest%%/*}
  case "$kind" in
    board-resources) res+=("$name") ;;              # JS/CSS first, so views re-sync against them
    board-displays|board-inputs)
      case "$name" in "Util - Schema - "*) schema+=("$name") ;; *) push+=("$name") ;; esac ;;   # new columns first
    board-tables) manual+=("$name (table schema change)") ;;
    lists) manual+=("$rel (board list — webeoc-lists push)") ;;
  esac
done < <(git diff --name-only "$base" "$head")
mapfile -t res < <(printf '%s\n' "${res[@]}" | sort -u | sed '/^$/d')
mapfile -t schema < <(printf '%s\n' "${schema[@]}" | sort -u | sed '/^$/d')
mapfile -t push < <(printf '%s\n' "${push[@]}" | sort -u | sed '/^$/d')
push=("${res[@]}" "${schema[@]}" "${push[@]}")
mapfile -t manual < <(printf '%s\n' "${manual[@]}" | sort -u | sed '/^$/d')

echo "push:   ${push[*]:-(none)}"
# test-push.sh claims (pre-MR test builds on the platform): this deploy supersedes them
slots="$root/.git/test-slots.tsv" tp="$here/../delegate/test-push.sh"
src_stream=$(awk '{print $5}' <<<"$status"); src_stream=${src_stream%→*}; src_stream=${src_stream#mr/}
if [ -s "$slots" ]; then
  for a in "${push[@]}"; do
    awk -F'\t' -v a="$a" -v s="$src_stream" '$1==a && $2!=s{print "warning: "a" is under test from "$2" — this deploy overwrites it; re-run test-push.sh push "$2}' "$slots"
  done
fi
[ ${#manual[@]} -eq 0 ] || printf 'needs PJF: %s\n' "${manual[@]}"
# the MR's own test steps, replayed for the live re-test after deploy
test_steps() {
  local t
  t=$("$gl" description "$iid" --section "How to test" 2>/dev/null) \
    || t=$("$gl" description "$iid" --section "Test steps" 2>/dev/null) || t=""
  if [ -n "$t" ]; then printf -- '--- how to test (!%s)\n%s\n' "$iid" "$t"
  else echo "--- no How to test section in !$iid"; fi
}
[ $dry -eq 0 ] || { test_steps; exit 0; }
[ ${#push[@]} -gt 0 ] || { test_steps; exit 0; }

# 4. targeted pushes
ps -eo args | grep -qiE '^[^ ]*(node[^ ]* )?[^ ]*weboard[^ ]* dev( |$)' && die "weboard dev is running — not pushing"
cd "$board_dir"
for a in "${push[@]}"; do
  out=$(weboard push "$a") || { echo "$out"; die "push failed: $a"; }
  echo "$out" | grep -F "🟢" | grep -v "Logged out" || true
  echo "$out" | grep -qF "$a successfully pushed" || { echo "$out"; die "push of $a didn't report success"; }
done
[ ! -s "$slots" ] || [ ! -x "$tp" ] || "$tp" clear "${push[@]}"
echo "deployed !$iid: ${#push[@]} asset(s)"
test_steps
