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
# between merge-base(dev, stream HEAD) and HEAD, in any boards/<dir>/; each is keyed "<dir>/<asset>" and
# pushed from its own board dir. Claims live in <git-common-dir>/test-slots.tsv.
# `push` refuses (exit 1, nothing pushed) when:
#   - the worktree has uncommitted tracked changes (the push must match a commit);
#   - an asset is claimed by ANOTHER stream (one live version per asset — test, then release/merge);
#   - dev changed an asset since the stream branched (pushing would revert dev's work live —
#     `git merge dev` in the worktree first);
#   - `weboard dev` is running.
# Disjoint streams can be under test at the same time. lists/ and groups/ are listed, not pushed.
# board-tables/ are pushed FIRST: a view push creates a missing table but with default settings (incident-
# DEPENDENT), ignoring the table's config.json (e.g. incidentIndependent); only the table push applies it.
# Schema views (`Util - Schema - *`) are pushed before other views so new columns exist first.
set -euo pipefail

die() { echo "test-push: $*" >&2; exit 1; }

main=$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd)
slots="$main/.git/test-slots.tsv"
touch "$slots"
dev=$(git -C "$main" branch --show-current)
shopt -s nullglob; boards=("$main"/boards/*/); shopt -u nullglob
[ ${#boards[@]} -gt 0 ] || die "no boards/*/ dir in $main"
for i in "${!boards[@]}"; do b=${boards[$i]%/}; boards[$i]=${b##*/}; done
# Claims written before multi-board support have a bare asset name: with one board, prefix it.
if awk -F'\t' '$1!~"/"{f=1} END{exit !f}' "$slots"; then
  [ ${#boards[@]} -eq 1 ] || die "$slots has pre-multi-board claims (no <dir>/) — prefix them by hand"
  tmp=$(mktemp); awk -F'\t' -v b="${boards[0]}" 'BEGIN{OFS="\t"} $1!~"/"{$1=b"/"$1} 1' "$slots" >"$tmp"; mv "$tmp" "$slots"
fi
# key "<dir>/<asset>" → board dir / asset name
kdir() { printf '%s' "${1%%/*}"; }
kname() { printf '%s' "${1#*/}"; }

weboard_running() { ps -eo args | grep -qiE '^[^ ]*(node[^ ]* )?[^ ]*weboard[^ ]* dev( |$)'; }

# assets <repo-dir> <base> <head> → "kind<TAB><dir>/<name>" lines (kind: table|res|schema|view|manual)
assets() {
  git -C "$1" diff --name-only "$2" "$3" -- boards groups | while IFS= read -r f; do
    case "$f" in groups/*.json) printf 'manual\t%s\n' "$f"; continue ;; esac   # webeoc-groups, non-atomic
    case "$f" in boards/*/*/*) ;; *) continue ;; esac                          # board-dir root files aren't assets
    rel=${f#boards/}; dir=${rel%%/*}; rel=${rel#*/}; kind=${rel%%/*}; rest=${rel#*/}; name=${rest%%/*}
    case "$kind" in
      board-resources) printf 'res\t%s/%s\n' "$dir" "$name" ;;
      board-displays|board-inputs)
        case "$name" in "Util - Schema - "*) printf 'schema\t%s/%s\n' "$dir" "$name" ;; *) printf 'view\t%s/%s\n' "$dir" "$name" ;; esac ;;
      board-tables) printf 'table\t%s/%s\n' "$dir" "$name" ;;                         # settings only land via a table push
      lists) printf 'manual\t%s/%s\n' "$dir" "$rel" ;;
    esac
  done | sort -u
}

# do_push <repo-dir> <key>...  — resources, then schema views, then views (caller orders them);
# each asset is pushed from its own boards/<dir>/
do_push() {
  local repo=$1; shift
  weboard_running && die "weboard dev is running — not pushing"
  for k in "$@"; do
    a=$(kname "$k"); dir="$repo/boards/$(kdir "$k")"
    out=$(cd "$dir" && env $(compgen -v | sed -n "s/^WE_/-u WE_/p") -u INIT_CWD weboard push "$a") || { echo "$out"; die "push failed: $k"; }  # env -u: dev .env only, never inherited (e.g. Test) creds
    echo "$out" | grep -qF "$a successfully pushed" || { echo "$out"; die "push of $k didn't report success"; }
    echo "  pushed $k"
  done
}

ordered() { awk -F'\t' '$1=="table"{print 0"\t"$2} $1=="res"{print 1"\t"$2} $1=="schema"{print 2"\t"$2} $1=="view"{print 3"\t"$2}' | sort | cut -f2; }

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
      # literal dir pathspecs: a glob like board-*/<asset> must match the whole file path, so it never matched
      b="boards/$(kdir "$a")" n=$(kname "$a")
      git -C "$main" diff --quiet "$mb" "$dev" -- ":(literal)$b/board-displays/$n" \
          ":(literal)$b/board-inputs/$n" ":(literal)$b/board-resources/$n" ":(literal)$b/board-tables/$n" \
        || bad+=("$a — changed on $dev since $stream branched (git merge $dev in the worktree)")
    done
    echo "$stream @ $(git -C "$wt" log --oneline -1 HEAD)"
    printf 'push:  %s\n' "${push[@]}"
    [ ${#manual[@]} -eq 0 ] || printf 'needs PJF: %s\n' "${manual[@]}"
    [ ${#bad[@]} -eq 0 ] || { printf 'blocked: %s\n' "${bad[@]}" >&2; exit 1; }
    [ $dry -eq 0 ] || exit 0
    mapfile -t pdirs < <(printf '%s\n' "${push[@]}" | cut -d/ -f1 | sort -u)
    for d in "${pdirs[@]}"; do   # *.env is git-ignored
      [ -e "$wt/boards/$d/.env" ] || ln -s "$main/boards/$d/.env" "$wt/boards/$d/.env"
    done
    do_push "$wt" "${push[@]}"
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
        found=0; for d in "$main/boards/$(kdir "$a")"/board-*/"$(kname "$a")"; do [ -e "$d" ] && found=1; done
        if [ $found -eq 1 ]; then keep+=("$a"); else gone+=("$a"); fi
      done
      mapfile -t keep < <(for a in "${keep[@]}"; do
        case "$(kname "$a")" in "Util - Schema - "*) printf '1\t%s\n' "$a" ;; *)
          if [ -d "$main/boards/$(kdir "$a")/board-resources/$(kname "$a")" ]; then printf '0\t%s\n' "$a"; else printf '2\t%s\n' "$a"; fi ;; esac
      done | sort | cut -f2)
      [ ${#keep[@]} -eq 0 ] || do_push "$main" "${keep[@]}"
      [ ${#gone[@]} -eq 0 ] || printf 'new asset, not on %s — delete in WebEOC admin if unwanted: %s\n' "$dev" "${gone[@]}"
    fi
    tmp=$(mktemp); awk -F'\t' -v s="$stream" '$2!=s' "$slots" >"$tmp"; mv "$tmp" "$slots"
    echo "released $stream (${#claimed[@]} asset(s))"
    ;;
  clear)
    [ $# -gt 0 ] || die "asset keys (<dir>/<asset>) required"
    tmp=$(mktemp)
    while IFS=$'\t' read -r a s sha t; do
      if printf '%s\n' "$@" | grep -qxF "$a"; then echo "cleared $a (was $s @ $sha)" >&2; else printf '%s\t%s\t%s\t%s\n' "$a" "$s" "$sha" "$t"; fi
    done <"$slots" >"$tmp"
    mv "$tmp" "$slots"
    ;;
  -h|--help|"") sed -n '2,23p' "$0" ;;
  *) die "unknown command $cmd" ;;
esac
