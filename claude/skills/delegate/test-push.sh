#!/usr/bin/env bash
# test-push.sh — put a stream's worktree build on the shared WebEOC platform for testing BEFORE its MR,
# with per-asset claims so concurrent test pushes can't overwrite each other.
#
# Usage (run from anywhere in the repo's MAIN checkout, which sits on the dev branch):
#   test-push.sh push <stream> [--dry-run]    targeted `weboard push` of every asset the stream changed
#   test-push.sh status                       who holds which asset on the platform right now
#   test-push.sh release <stream> [--restore] drop the stream's claims; --restore re-pushes the dev
#                                             branch's version of each claimed asset (rejected/abandoned work)
#   test-push.sh clear <asset>...             drop claims on assets dev has since re-pushed (merge-and-deploy)
#
# <stream> = worktree name (.claude/worktrees/<stream>). Assets = board-displays/inputs/resources changed
# between merge-base(dev, stream HEAD) and HEAD. Claims live in <git-common-dir>/test-slots.tsv.
# `push` refuses (exit 1, nothing pushed) when:
#   - the worktree has uncommitted tracked changes (the push must match a commit);
#   - an asset is claimed by ANOTHER stream (one live version per asset — test, then release/merge);
#   - dev changed an asset since the stream branched (pushing would revert dev's work live —
#     `git merge dev` in the worktree first);
#   - `weboard dev` is running.
# Disjoint streams can be under test at the same time. board-tables/ and lists/ are listed, not pushed.
# Schema views (`Util - Schema - *`) are pushed before other views so new columns exist first.
set -euo pipefail

die() { echo "test-push: $*" >&2; exit 1; }

main=$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd)
slots="$main/.git/test-slots.tsv"
touch "$slots"
dev=$(git -C "$main" branch --show-current)
dirs=("$main"/boards/*/); [ ${#dirs[@]} -eq 1 ] && [ -d "${dirs[0]}" ] || die "expected one boards/*/ dir"
board_rel=${dirs[0]#"$main"/}; board_rel=${board_rel%/}

weboard_running() { ps -eo args | grep -qiE '^[^ ]*(node[^ ]* )?[^ ]*weboard[^ ]* dev( |$)'; }

# assets <repo-dir> <base> <head> → "kind<TAB>name" lines (kind: res|schema|view|manual)
assets() {
  git -C "$1" diff --name-only "$2" "$3" -- "$board_rel" | while IFS= read -r f; do
    rel=${f#"$board_rel"/}; kind=${rel%%/*}; rest=${rel#*/}; name=${rest%%/*}
    case "$kind" in
      board-resources) printf 'res\t%s\n' "$name" ;;
      board-displays|board-inputs)
        case "$name" in "Util - Schema - "*) printf 'schema\t%s\n' "$name" ;; *) printf 'view\t%s\n' "$name" ;; esac ;;
      board-tables|lists) printf 'manual\t%s\n' "$rel" ;;
    esac
  done | sort -u
}

# do_push <board-dir> <asset>...  — resources, then schema views, then views (caller orders them)
do_push() {
  local dir=$1; shift
  weboard_running && die "weboard dev is running — not pushing"
  for a in "$@"; do
    out=$(cd "$dir" && weboard push "$a") || { echo "$out"; die "push failed: $a"; }
    echo "$out" | grep -qF "$a successfully pushed" || { echo "$out"; die "push of $a didn't report success"; }
    echo "  pushed $a"
  done
}

ordered() { awk -F'\t' '$1=="res"{print 0"\t"$2} $1=="schema"{print 1"\t"$2} $1=="view"{print 2"\t"$2}' | sort | cut -f2; }

cmd=${1:-}; shift || true
case "$cmd" in
  push)
    stream=${1:-}; [ -n "$stream" ] || die "stream name required"; dry=0; [ "${2:-}" = --dry-run ] && dry=1
    wt="$main/.claude/worktrees/$stream"; [ -d "$wt" ] || die "no worktree $wt"
    [ -z "$(git -C "$wt" status --porcelain --untracked-files=no)" ] || die "$stream has uncommitted tracked changes — commit first"
    head=$(git -C "$wt" rev-parse HEAD); mb=$(git -C "$wt" merge-base "$dev" HEAD)
    list=$(assets "$wt" "$mb" HEAD)
    mapfile -t push < <(ordered <<<"$list")
    mapfile -t manual < <(awk -F'\t' '$1=="manual"{print $2}' <<<"$list")
    [ ${#push[@]} -gt 0 ] || die "$stream changes no pushable assets"
    bad=()
    for a in "${push[@]}"; do
      owner=$(awk -F'\t' -v a="$a" '$1==a{print $2}' "$slots")
      [ -z "$owner" ] || [ "$owner" = "$stream" ] || bad+=("$a — claimed by $owner")
      git -C "$main" diff --quiet "$mb" "$dev" -- "$board_rel/board-*/$a" \
        || bad+=("$a — changed on $dev since $stream branched (git merge $dev in the worktree)")
    done
    echo "$stream @ $(git -C "$wt" log --oneline -1 HEAD)"
    printf 'push:  %s\n' "${push[@]}"
    [ ${#manual[@]} -eq 0 ] || printf 'needs PJF: %s\n' "${manual[@]}"
    [ ${#bad[@]} -eq 0 ] || { printf 'blocked: %s\n' "${bad[@]}" >&2; exit 1; }
    [ $dry -eq 0 ] || exit 0
    [ -e "$wt/$board_rel/.env" ] || ln -s "$main/$board_rel/.env" "$wt/$board_rel/.env"   # *.env is git-ignored
    do_push "$wt/$board_rel" "${push[@]}"
    now=$(date '+%F %H:%M')
    tmp=$(mktemp)
    awk -F'\t' -v s="$stream" '$2!=s' "$slots" >"$tmp"
    awk -F'\t' -v s="$stream" '$2==s' "$slots" | while IFS=$'\t' read -r a _ _ _; do
      printf '%s\n' "${push[@]}" | grep -qxF "$a" || printf '%s\t%s\t%s\t%s\n' "$a" "$stream" "${head:0:7}" "$now"
    done >>"$tmp"
    for a in "${push[@]}"; do printf '%s\t%s\t%s\t%s\n' "$a" "$stream" "${head:0:7}" "$now"; done >>"$tmp"
    mv "$tmp" "$slots"
    echo "under test: $stream (${#push[@]} asset(s))"
    ;;
  status)
    [ -s "$slots" ] || { echo "platform = $dev (no test claims)"; exit 0; }
    sort -t$'\t' -k2,2 -k1,1 "$slots" | awk -F'\t' '{ if ($2!=p) {print $2" @ "$3" ("$4")"; p=$2} print "  "$1 }'
    ;;
  release)
    stream=${1:-}; [ -n "$stream" ] || die "stream name required"
    mapfile -t claimed < <(awk -F'\t' -v s="$stream" '$2==s{print $1}' "$slots")
    [ ${#claimed[@]} -gt 0 ] || { echo "$stream holds no claims"; exit 0; }
    if [ "${2:-}" = --restore ]; then
      [ -z "$(git -C "$main" status --porcelain --untracked-files=no)" ] || die "main checkout has tracked changes"
      keep=() gone=()
      for a in "${claimed[@]}"; do
        found=0; for d in "$main/$board_rel"/board-*/"$a"; do [ -e "$d" ] && found=1; done
        if [ $found -eq 1 ]; then keep+=("$a"); else gone+=("$a"); fi
      done
      mapfile -t keep < <(for a in "${keep[@]}"; do
        case "$a" in "Util - Schema - "*) printf '1\t%s\n' "$a" ;; *)
          if [ -d "$main/$board_rel/board-resources/$a" ]; then printf '0\t%s\n' "$a"; else printf '2\t%s\n' "$a"; fi ;; esac
      done | sort | cut -f2)
      [ ${#keep[@]} -eq 0 ] || do_push "$main/$board_rel" "${keep[@]}"
      [ ${#gone[@]} -eq 0 ] || printf 'new asset, not on %s — delete in WebEOC admin if unwanted: %s\n' "$dev" "${gone[@]}"
    fi
    tmp=$(mktemp); awk -F'\t' -v s="$stream" '$2!=s' "$slots" >"$tmp"; mv "$tmp" "$slots"
    echo "released $stream (${#claimed[@]} asset(s))"
    ;;
  clear)
    [ $# -gt 0 ] || die "asset names required"
    tmp=$(mktemp)
    while IFS=$'\t' read -r a s sha t; do
      if printf '%s\n' "$@" | grep -qxF "$a"; then echo "cleared $a (was $s @ $sha)" >&2; else printf '%s\t%s\t%s\t%s\n' "$a" "$s" "$sha" "$t"; fi
    done <"$slots" >"$tmp"
    mv "$tmp" "$slots"
    ;;
  -h|--help|"") sed -n '2,22p' "$0" ;;
  *) die "unknown command $cmd" ;;
esac
