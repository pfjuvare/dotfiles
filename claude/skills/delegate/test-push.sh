#!/usr/bin/env bash
# test-push.sh — put a stream's worktree build on the shared WebEOC platform for testing BEFORE its MR,
# with per-asset claims so concurrent test pushes can't overwrite each other.
#
# Usage (run from anywhere in the repo's MAIN checkout, which sits on the dev branch):
#   test-push.sh push <stream> [--dry-run] [--overwrite-live]
#                                             targeted `weboard push` of every asset the stream changed
#   test-push.sh integrate <stream>           3-way merge the live (platform) version of each conflicting asset
#                                             into the stream's worktree, after `push` stopped on a conflict
#   test-push.sh status                       who holds which asset on the platform right now
#   test-push.sh release <stream> [--restore] drop the stream's claims; --restore puts back what was live
#                                             before the stream's first push (rejected/abandoned work)
#   test-push.sh before <stream> [--dry-run]  put back what was live before the stream's first push, but KEEP
#                                             the claims (before/after comparison)
#   test-push.sh after <stream> [--dry-run]   put the stream's build back (same as push)
#   test-push.sh clear <asset>...             drop claims on assets dev has since re-pushed (merge-and-deploy)
#
# <stream> = worktree name (.claude/worktrees/<stream>). Assets = board-displays/inputs/resources changed
# between merge-base(dev, stream HEAD) and HEAD, in any boards/<dir>/; each is keyed "<dir>/<asset>" and
# pushed from its own board dir. Claims live in <git-common-dir>/test-slots.tsv
# (asset, stream, sha, time, state = after|before; a missing state means after).
# `push` refuses (exit 1, nothing pushed) when:
#   - the worktree has uncommitted tracked changes (the push must match a commit);
#   - an asset is claimed by ANOTHER stream (one live version per asset — test, then release/merge);
#   - dev changed an asset since the stream branched (pushing would revert dev's work live —
#     `git merge dev` in the worktree first);
#   - `weboard dev` is running;
#   - (exit 3) the LIVE version of an asset it's about to take differs from the dev branch: someone pushed
#     work that isn't in your dev (your dev is behind origin, or it was never committed). Nothing is
#     pushed; it says which assets and why, and the options: `integrate`, `--overwrite-live`, or ask.
# Snapshots: the first push of an asset pulls the live board once (`weboard pull`, no retries) into
# <git-common-dir>/test-snapshots/<stream>/ and keeps the live version of each asset the stream takes.
# `before` and `release --restore` push that snapshot back, so the platform returns to exactly what was
# live, colleagues' changes included. Claims from before snapshots existed fall back to the dev version.
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

snaps="$main/.git/test-snapshots"
asset_dir() { local d; for d in "$1"/board-*/"$2"; do [ -e "$d" ] && { printf '%s' "$d"; return 0; }; done; return 1; }
# Same asset content, whitespace aside (weboard's pull formatting isn't byte-identical to the repo's).
same_asset() { [ -n "$1" ] && [ -n "$2" ] && diff -rqwB "$1" "$2" >/dev/null; }
snap_state() { awk -F'\t' -v k="$2" '$1==k{print $2}' "$snaps/$1/index" 2>/dev/null | tail -1; }

# snapshot <stream> <key>... → for keys not yet snapshotted: pull each board's live version once into a
# scratch copy and keep the live asset in $snaps/<stream>/boards/<dir>/ (a pushable board dir). Records
# "<key>\tlive|absent" in $snaps/<stream>/index.
snapshot() {
  local stream=$1; shift
  local root="$snaps/$stream" k d n live kind f out
  mkdir -p "$root"; touch "$root/index"
  local need=(); for k in "$@"; do [ -n "$(snap_state "$stream" "$k")" ] || need+=("$k"); done
  [ ${#need[@]} -gt 0 ] || return 0
  mapfile -t ndirs < <(printf '%s\n' "${need[@]}" | cut -d/ -f1 | sort -u)
  for d in "${ndirs[@]}"; do
    local pull="$root/.pull-$d"; rm -rf "${root:?}/.pull-${d:?}"; mkdir -p "$pull" "$root/boards/$d"
    # the board's root config (webeoc.board.json, .env…), not its assets
    for f in "$main/boards/$d"/* "$main/boards/$d"/.env; do
      case "${f##*/}" in board-*|node_modules|logs|*.md) continue ;; esac
      [ -f "$f" ] && { cp "$f" "$pull/"; [ -e "$root/boards/$d/${f##*/}" ] || cp "$f" "$root/boards/$d/"; }
    done
    echo "  snapshot: pulling the live $d board once (to keep what's live now)"
    out=$(cd "$pull" && env $(compgen -v | sed -n "s/^WE_/-u WE_/p") -u INIT_CWD weboard pull --force --retry-count 0 --backup-path "$pull/.bak" 2>&1) \
      || { echo "$out" | tail -5; die "snapshot pull of $d failed (on an Imperva/Incapsula 403, stop: don't retry)"; }
    for k in "${need[@]}"; do
      [ "$(kdir "$k")" = "$d" ] || continue
      n=$(kname "$k")
      if live=$(asset_dir "$pull" "$n"); then
        kind=$(basename "$(dirname "$live")")
        mkdir -p "$root/boards/$d/$kind"
        rm -rf "${root:?}/boards/${d:?}/${kind:?}/${n:?}"; cp -R "$live" "$root/boards/$d/$kind/"
        printf '%s\tlive\n' "$k" >>"$root/index"
      else printf '%s\tabsent\n' "$k" >>"$root/index"; fi
    done
    rm -rf "${root:?}/.pull-${d:?}"
  done
}

# conflicts <stream> <key>... → "<key>\t<reason>" for live versions that differ from dev
conflicts() {
  local stream=$1; shift
  local k st live devd od tmp fetched=0
  for k in "$@"; do
    st=$(snap_state "$stream" "$k"); live=$(asset_dir "$snaps/$stream/boards/$(kdir "$k")" "$(kname "$k")" || true)
    devd=$(asset_dir "$main/boards/$(kdir "$k")" "$(kname "$k")" || true)
    if [ "$st" = absent ]; then
      [ -z "$devd" ] || printf '%s\tnot on the platform, though it is on %s (deleted live?)\n' "$k" "$dev"
      continue
    fi
    [ -n "$devd" ] || { printf '%s\tlive on the platform but not on %s: someone created it there\n' "$k" "$dev"; continue; }
    same_asset "$live" "$devd" && continue
    [ $fetched -eq 1 ] || { git -C "$main" fetch -q origin "$dev" 2>/dev/null || true; fetched=1; }
    tmp=$(mktemp -d); od=""
    if git -C "$main" rev-parse -q --verify "origin/$dev" >/dev/null; then
      git -C "$main" archive "origin/$dev" -- "boards/$(kdir "$k")" 2>/dev/null | tar -x -C "$tmp" 2>/dev/null || true
      od=$(asset_dir "$tmp/boards/$(kdir "$k")" "$(kname "$k")" || true)
    fi
    if same_asset "$live" "$od"; then printf '%s\tlive = origin/%s, but your local %s is behind: git pull in the main checkout, then git merge %s in the worktree\n' "$k" "$dev" "$dev" "$dev"
    else printf '%s\tlive differs from %s: pushed by someone without committing it (or from an unmerged branch)\n' "$k" "$dev"; fi
    rm -rf "${tmp:?}"
  done
}

# restore_keys <stream> → the stream's claimed keys in push order, as "snap\t<key>" (put back from the
# snapshot) or "dev\t<key>" (no snapshot: dev's version); keys with nothing to put back go to stderr.
restore_keys() {
  local k st b n sb
  while IFS= read -r k; do
    st=$(snap_state "$1" "$k")
    if [ "$st" = live ]; then printf 'snap\t%s\n' "$k"
    elif [ "$st" = absent ]; then echo "$k" >&2
    elif asset_dir "$main/boards/$(kdir "$k")" "$(kname "$k")" >/dev/null; then printf 'dev\t%s\n' "$k"
    else echo "$k" >&2; fi
  done < <(awk -F'\t' -v s="$1" '$2==s{print $1}' "$slots" | while IFS= read -r k; do
    b="$main/boards/$(kdir "$k")" sb="$snaps/$1/boards/$(kdir "$k")" n=$(kname "$k")
    if [ -d "$b/board-tables/$n" ] || [ -d "$sb/board-tables/$n" ]; then printf '0\t%s\n' "$k"
    elif [ -d "$b/board-resources/$n" ] || [ -d "$sb/board-resources/$n" ]; then printf '1\t%s\n' "$k"
    else case "$n" in "Util - Schema - "*) printf '2\t%s\n' "$k" ;; *) printf '3\t%s\n' "$k" ;; esac; fi
  done | sort | cut -f2)
}
# put_back <stream> < restore_keys lines: push each before version, from the snapshot or dev
put_back() {
  local src k
  while IFS=$'\t' read -r src k; do
    if [ "$src" = snap ]; then
      [ -e "$snaps/$1/boards/$(kdir "$k")/.env" ] || ln -s "$main/boards/$(kdir "$k")/.env" "$snaps/$1/boards/$(kdir "$k")/.env"
      do_push "$snaps/$1" "$k"
    else do_push "$main" "$k"; fi
  done
}

# set_state <stream> <after|before>
set_state() {
  local tmp; tmp=$(mktemp)
  awk -F'\t' -v s="$1" -v st="$2" 'BEGIN{OFS="\t"} $2==s{$5=st} {print}' "$slots" >"$tmp"; mv "$tmp" "$slots"
}

ordered() { awk -F'\t' '$1=="table"{print 0"\t"$2} $1=="res"{print 1"\t"$2} $1=="schema"{print 2"\t"$2} $1=="view"{print 3"\t"$2}' | sort | cut -f2; }

cmd=${1:-}; shift || true
case "$cmd" in
  push)
    stream=${1:-}; [ -n "$stream" ] || die "stream name required"; dry=0; force=0
    for o in "${@:2}"; do case "$o" in --dry-run) dry=1 ;; --overwrite-live) force=1 ;; *) die "unknown option $o" ;; esac; done
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
    weboard_running && die "weboard dev is running — not pushing"
    # Keep what's live before taking an asset; stop if it holds work that isn't on dev.
    fresh=(); for a in "${push[@]}"; do [ -n "$(snap_state "$stream" "$a")" ] || fresh+=("$a"); done
    if [ ${#fresh[@]} -gt 0 ]; then
      [ -z "$(git -C "$main" status --porcelain --untracked-files=no)" ] || die "main checkout has tracked changes (needed to compare the live board with $dev)"
      snapshot "$stream" "${fresh[@]}"
    fi
    # Compare with dev: assets taken for the first time, and ones an earlier push stopped on (re-checked,
    # so pulling dev clears them) until `integrate` or --overwrite-live settles them.
    check=("${fresh[@]}")
    if [ -s "$snaps/$stream/conflicts" ]; then
      while IFS= read -r a; do printf '%s\n' "${push[@]}" | grep -qxF "$a" && check+=("$a"); done <"$snaps/$stream/conflicts"
    fi
    clash=""
    if [ ${#check[@]} -gt 0 ]; then mapfile -t check < <(printf '%s\n' "${check[@]}" | sort -u); clash=$(conflicts "$stream" "${check[@]}"); fi
    if [ -n "$clash" ] && [ $force -eq 0 ]; then
      echo "conflict: the live platform has work that isn't on $dev; nothing pushed" >&2
      while IFS=$'\t' read -r a why; do echo "  $a — $why" >&2; done <<<"$clash"
      echo "live copies kept in $snaps/$stream/boards/ (diff them against the worktree)" >&2
      echo "options: 1) if dev is behind: pull dev, git merge dev in the worktree, push again" >&2
      echo "         2) test-push integrate $stream: 3-way merge the live change into the stream, review, commit, push again" >&2
      echo "         3) test-push push $stream --overwrite-live: push anyway (before / release --restore put the live version back)" >&2
      echo "         4) ask whoever pushed it" >&2
      cut -f1 <<<"$clash" >"$snaps/$stream/conflicts"
      exit 3
    fi
    [ ! -e "$snaps/$stream/conflicts" ] || : >"$snaps/$stream/conflicts"
    mapfile -t pdirs < <(printf '%s\n' "${push[@]}" | cut -d/ -f1 | sort -u)
    for d in "${pdirs[@]}"; do   # *.env is git-ignored
      [ -e "$wt/boards/$d/.env" ] || ln -s "$main/boards/$d/.env" "$wt/boards/$d/.env"
    done
    do_push "$wt" "${push[@]}"
    now=$(date '+%F %H:%M')
    tmp=$(mktemp)
    awk -F'\t' -v s="$stream" '$2!=s' "$slots" >"$tmp"
    awk -F'\t' -v s="$stream" '$2==s' "$slots" | while IFS=$'\t' read -r a _ _ _ _; do
      printf '%s\n' "${push[@]}" | grep -qxF "$a" || printf '%s\t%s\t%s\t%s\tafter\n' "$a" "$stream" "${head:0:7}" "$now"
    done >>"$tmp"
    for a in "${push[@]}"; do printf '%s\t%s\t%s\t%s\tafter\n' "$a" "$stream" "${head:0:7}" "$now"; done >>"$tmp"
    mv "$tmp" "$slots"
    echo "under test: $stream (${#push[@]} asset(s))"
    ;;
  status)
    [ -s "$slots" ] || { echo "platform = $dev (no test claims)"; exit 0; }
    sort -t$'\t' -k2,2 -k1,1 "$slots" | awk -F'\t' -v dev="$dev" '{ if ($2!=p) {st=($5=="before" ? "BEFORE: "dev"'"'"'s version live" : "after: stream build live"); print $2" @ "$3" ("$4") — "st; p=$2} print "  "$1 }'
    ;;
  release)
    stream=${1:-}; [ -n "$stream" ] || die "stream name required"
    mapfile -t claimed < <(awk -F'\t' -v s="$stream" '$2==s{print $1}' "$slots")
    [ ${#claimed[@]} -gt 0 ] || { echo "$stream holds no claims"; exit 0; }
    if [ "${2:-}" = --restore ]; then
      [ -z "$(git -C "$main" status --porcelain --untracked-files=no)" ] || die "main checkout has tracked changes"
      gonef=$(mktemp); plan=$(restore_keys "$stream" 2>"$gonef"); mapfile -t gone <"$gonef"; rm -f "${gonef:?}"
      [ -z "$plan" ] || put_back "$stream" <<<"$plan"
      [ ${#gone[@]} -eq 0 ] || printf 'new asset, not live before the stream — delete in WebEOC admin if unwanted: %s\n' "${gone[@]}"
    fi
    tmp=$(mktemp); awk -F'\t' -v s="$stream" '$2!=s' "$slots" >"$tmp"; mv "$tmp" "$slots"
    rm -rf "${snaps:?}/${stream:?}"
    echo "released $stream (${#claimed[@]} asset(s))"
    ;;
  before)
    stream=${1:-}; [ -n "$stream" ] || die "stream name required"; dry=0; [ "${2:-}" = --dry-run ] && dry=1
    awk -F'\t' -v s="$stream" '$2==s{f=1} END{exit !f}' "$slots" || die "$stream holds no claims: test-push push it first"
    [ -z "$(git -C "$main" status --porcelain --untracked-files=no)" ] || die "main checkout has tracked changes"
    gonef=$(mktemp); plan=$(restore_keys "$stream" 2>"$gonef"); mapfile -t gone <"$gonef"; rm -f "${gonef:?}"
    echo "$stream: before = what was live before its first push (snapshot), else $dev @ $(git -C "$main" log --oneline -1 HEAD)"
    [ -z "$plan" ] || while IFS=$'\t' read -r src k; do echo "push:  $k ($([ "$src" = snap ] && echo "live snapshot" || echo "$dev's version"))"; done <<<"$plan"
    [ ${#gone[@]} -eq 0 ] || printf 'new in %s, no before version (stays as the stream build): %s\n' "$stream" "${gone[@]}"
    [ $dry -eq 0 ] || exit 0
    [ -z "$plan" ] || put_back "$stream" <<<"$plan"
    set_state "$stream" before
    echo "before: the pre-test version is live for $stream (claims kept; test-push after $stream to put the build back)"
    ;;
  after)
    exec "$0" push "$@"
    ;;
  integrate)
    stream=${1:-}; [ -n "$stream" ] || die "stream name required"
    wt="$main/.claude/worktrees/$stream"; [ -d "$wt" ] || die "no worktree $wt"
    [ -s "$snaps/$stream/conflicts" ] || die "no conflict recorded for $stream (run test-push push $stream first)"
    [ -z "$(git -C "$wt" status --porcelain --untracked-files=no)" ] || die "$stream has uncommitted tracked changes — commit first"
    mb=$(git -C "$wt" merge-base "$dev" HEAD); clean=1
    while IFS= read -r k; do
      live=$(asset_dir "$snaps/$stream/boards/$(kdir "$k")" "$(kname "$k")") || { echo "  $k: not live, nothing to merge"; continue; }
      rel=${live#"$snaps/$stream/"}
      while IFS= read -r f; do
        r="$rel/${f#"$live"/}"; mine="$wt/$r"; base=$(mktemp)
        git -C "$main" show "$mb:$r" >"$base" 2>/dev/null || : >"$base"
        if [ ! -e "$mine" ]; then mkdir -p "$(dirname "$mine")"; cp "$f" "$mine"; echo "  added $r (live only)"
        elif git merge-file -L stream -L base -L live "$mine" "$base" "$f"; then echo "  merged $r"
        else clean=0; echo "  CONFLICT $r (markers left in the file)"; fi
        rm -f "${base:?}"
      done < <(find "$live" -type f)
    done <"$snaps/$stream/conflicts"
    : >"$snaps/$stream/conflicts"   # taken into the stream: the next push carries the live change
    if [ $clean -eq 1 ]; then echo "integrated: review the diff in $stream, commit, then test-push push $stream"
    else echo "integrated with conflicts: resolve the markers in $stream, commit, then test-push push $stream"; fi
    ;;
  clear)
    [ $# -gt 0 ] || die "asset keys (<dir>/<asset>) required"
    tmp=$(mktemp); cleared=()
    while IFS=$'\t' read -r a s sha t st; do
      if printf '%s\n' "$@" | grep -qxF "$a"; then echo "cleared $a (was $s @ $sha)" >&2; cleared+=("$s"); else printf '%s\t%s\t%s\t%s\t%s\n' "$a" "$s" "$sha" "$t" "${st:-after}"; fi
    done <"$slots" >"$tmp"
    mv "$tmp" "$slots"
    # a stream with no claims left has no use for its snapshot
    for s in $(printf '%s\n' "${cleared[@]}" | sort -u); do
      awk -F'\t' -v s="$s" '$2==s{f=1} END{exit !f}' "$slots" || rm -rf "${snaps:?}/${s:?}"
    done
    ;;
  -h|--help|"") sed -n '2,38p' "$0" ;;
  *) die "unknown command $cmd" ;;
esac
