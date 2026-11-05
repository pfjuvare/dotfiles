#!/usr/bin/env bash
# test-push.test.sh — exercises test-push.sh against a throwaway repo with a fake `weboard` backed by a fake
# platform dir: push copies the asset there (and logs which version), pull copies the whole board back.
# Never touches a real platform. Run: bash test-push.test.sh
set -euo pipefail

TP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-push.sh"
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# fake weboard: `push <asset>` logs "<asset>=<first line of its file>" and copies it to the platform;
# `pull` copies the platform's board into the current dir and logs "pull".
mkdir -p "$T/bin" "$T/platform"
cat >"$T/bin/weboard" <<'EOF'
#!/usr/bin/env bash
plat="${FAKE_PLATFORM:?}/$(cat webeoc.board.json)"
case "$1" in
  push)
    d=$(ls -d board-*/"$2" 2>/dev/null | head -1); f=$(ls -d "$d"/* | grep -v /config.json | head -1); [ -n "$f" ] || f="$d/config.json"
    echo "$2=$(head -1 "$f")" >>"$WEBOARD_LOG"
    mkdir -p "$plat/$(dirname "$d")"; rm -rf "${plat:?}/${d:?}"; cp -R "$d" "$plat/$(dirname "$d")/"
    echo "$2 successfully pushed" ;;
  pull) echo pull >>"$PULL_LOG"; cp -R "$plat"/. . ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$T/bin/weboard"
export PATH="$T/bin:$PATH" WEBOARD_LOG="$T/log" PULL_LOG="$T/pulls" FAKE_PLATFORM="$T/platform"
: >"$PULL_LOG"

git init -q --bare "$T/origin.git"
repo="$T/repo"; mkdir -p "$repo/boards/b1/board-displays/View A" "$repo/boards/b1/board-resources/Res"
cd "$repo"
git init -q -b dev
git config user.email t@t; git config user.name t
echo b1 >boards/b1/webeoc.board.json
echo '{"board":"b1"}' >boards/b1/board-config.json
echo dev-view >"boards/b1/board-displays/View A/view.xhtml"
printf 'dev-res\nline2\nline3\nline4\nline5\n' >"boards/b1/board-resources/Res/res.js"
mkdir -p "boards/b1/board-tables/ZTbl"; echo dev-tbl >"boards/b1/board-tables/ZTbl/config.json"
echo 'WE_URL=x' >boards/b1/.env; echo '.env' >.gitignore
git add -A; git commit -qm base
git remote add origin "$T/origin.git"; git push -q origin dev
# the platform starts as dev, as `weboard pull` returns it: config with platform-only keys and filters
# sorted, code reformatted
mkdir -p "$T/platform/b1"; cp -R boards/b1/board-displays boards/b1/board-resources boards/b1/board-tables "$T/platform/b1/"
printf '{"name":"View A","viewFilters":[{"name":"B"},{"name":"A"}],"contentType":"x"}\n' >"boards/b1/board-displays/View A/config.json"
git add -A; git commit -qm "view config"; git push -q origin dev
printf '{\n  "globalid": "g-1",\n  "name": "View A",\n  "viewFilters": [{"name": "A"}, {"name": "B"}],\n  "contenttype": "x",\n  "thumbnail": {"icon": "t"}\n}\n' >"$T/platform/b1/board-displays/View A/config.json"
printf 'dev-res\nline2\nline3\nline4\nline5\n\n' >"$T/platform/b1/board-resources/Res/res.js"
git worktree add -q .claude/worktrees/s1 -b worktree-s1
( cd .claude/worktrees/s1
  echo stream-view >"boards/b1/board-displays/View A/view.xhtml"
  mkdir -p "boards/b1/board-displays/View B"; echo stream-new >"boards/b1/board-displays/View B/view.xhtml"
  echo stream-tbl >"boards/b1/board-tables/ZTbl/config.json"
  git add -A; git commit -qm change )
git worktree add -q .claude/worktrees/s2 -b worktree-s2
( cd .claude/worktrees/s2
  echo other >"boards/b1/board-displays/View A/view.xhtml"; git add -A; git commit -qm other )
last() { tail -n "$1" "$WEBOARD_LOG" | sort | tr '\n' ' '; }
pulls() { wc -l <"$PULL_LOG" | tr -d ' '; }

"$TP" push s1 >/dev/null
check "push: table first, then the stream build of both views" '[ "$(head -1 "$WEBOARD_LOG")" = "ZTbl=stream-tbl" ] && [ "$(last 2)" = "View A=stream-view View B=stream-new " ]'
check "push: the live board is pulled once to snapshot it" '[ "$(pulls)" = 1 ]'
check "push: the snapshot keeps the board's config files (board-config.json too)" '[ -f .git/test-snapshots/s1/boards/b1/board-config.json ] && [ -f .git/test-snapshots/s1/boards/b1/webeoc.board.json ]'
check "push: snapshot records the new view as not live before" 'grep -q "b1/View B	absent" .git/test-snapshots/s1/index && grep -q "b1/View A	live" .git/test-snapshots/s1/index'

: >"$WEBOARD_LOG"
"$TP" push s1 >/dev/null
check "re-push: no second pull for assets already snapshotted" '[ "$(pulls)" = 1 ]'

: >"$WEBOARD_LOG"
out=$("$TP" before s1 --dry-run)
check "before --dry-run pushes nothing" '[ ! -s "$WEBOARD_LOG" ]'
check "before --dry-run lists the new view as having no before version" 'grep -q "no before version.*View B" <<<"$out"'
check "before --dry-run says it puts back the live snapshot" 'grep -q "View A (live snapshot)" <<<"$out"'

"$TP" before s1 >/dev/null
check "before: the snapshot's table first, then View A (View B has no before)" '[ "$(cat "$WEBOARD_LOG" | tr "\n" " ")" = "ZTbl=dev-tbl View A=dev-view " ]'
check "before: claims kept" '[ "$(awk -F"\t" "\$2==\"s1\"" .git/test-slots.tsv | wc -l)" -eq 3 ]'
check "before: state recorded" '! awk -F"\t" "\$2==\"s1\" && \$5!=\"before\"{f=1} END{exit !f}" .git/test-slots.tsv'
check "status shows BEFORE" '"$TP" status | grep -q "s1 .*BEFORE"'
check "another stream still can't take a claimed asset" '! "$TP" push s2 >/dev/null 2>&1'

: >"$WEBOARD_LOG"
"$TP" after s1 >/dev/null
check "after: stream build back" '[ "$(last 2)" = "View A=stream-view View B=stream-new " ]'
check "after: state back to after" '"$TP" status | grep -q "s1 .*after"'

"$TP" clear "b1/View B" 2>/dev/null
check "clear keeps the state column" '[ "$(awk -F"\t" "{print NF}" .git/test-slots.tsv | sort -u)" = 5 ]'

: >"$WEBOARD_LOG"
"$TP" release s1 --restore >/dev/null
check "release --restore puts the snapshot back, table first" '[ "$(cat "$WEBOARD_LOG" | tr "\n" " ")" = "ZTbl=dev-tbl View A=dev-view " ]'
check "release drops the claims and the snapshot" '[ ! -s .git/test-slots.tsv ] && [ ! -d .git/test-snapshots/s1 ]'

check "before refuses a stream with no claims" '! "$TP" before s1 >/dev/null 2>&1'

# --- a colleague's work on the live platform that isn't on dev ---------------------------------------
git worktree add -q .claude/worktrees/s3 -b worktree-s3
( cd .claude/worktrees/s3
  printf 'dev-res\nline2\nline3\nline4\nstream-line5\n' >"boards/b1/board-resources/Res/res.js"
  git add -A; git commit -qm s3 )
printf 'colleague-line1\nline2\nline3\nline4\nline5\n' >"$T/platform/b1/board-resources/Res/res.js"
: >"$WEBOARD_LOG"
set +e; out=$("$TP" push s3 2>&1); rc=$?; set -e
check "conflict: push stops with exit 3 and pushes nothing" '[ $rc -eq 3 ] && [ ! -s "$WEBOARD_LOG" ]'
check "conflict: says which asset and that it isn't on dev" 'grep -q "b1/Res — live differs from dev: pushed by someone without committing" <<<"$out"'
check "conflict: offers the options" 'grep -q "test-push integrate s3" <<<"$out" && grep -q -- "--overwrite-live" <<<"$out"'
check "conflict: claims nothing" '! grep -q "	s3	" .git/test-slots.tsv'

"$TP" integrate s3 >/dev/null
check "integrate: 3-way merge keeps both the colleague's and the stream's change" \
  '[ "$(head -1 .claude/worktrees/s3/boards/b1/board-resources/Res/res.js)" = colleague-line1 ] && [ "$(tail -1 .claude/worktrees/s3/boards/b1/board-resources/Res/res.js)" = stream-line5 ]'
( cd .claude/worktrees/s3; git commit -qam "integrate live Res" )
: >"$WEBOARD_LOG"
"$TP" push s3 >/dev/null
check "after integrating, the push goes ahead with the merged build" '[ "$(cat "$WEBOARD_LOG")" = "Res=colleague-line1" ] && [ "$(tail -1 "$T/platform/b1/board-resources/Res/res.js")" = stream-line5 ]'
: >"$WEBOARD_LOG"
"$TP" before s3 >/dev/null
check "before puts the colleague's live version back, not dev's" '[ "$(cat "$WEBOARD_LOG")" = "Res=colleague-line1" ] && [ "$(tail -1 "$T/platform/b1/board-resources/Res/res.js")" = line5 ]'
"$TP" release s3 --restore >/dev/null
check "release --restore leaves the colleague's version live" '[ "$(head -1 "$T/platform/b1/board-resources/Res/res.js")" = colleague-line1 ] && [ "$(tail -1 "$T/platform/b1/board-resources/Res/res.js")" = line5 ]'

# --- live = origin/dev, but the local dev is behind ---------------------------------------------------
git clone -q -b dev "$T/origin.git" "$T/other"
( cd "$T/other"; git config user.email o@o; git config user.name o
  mkdir -p "boards/b1/board-displays/View A"; echo colleague-view >"boards/b1/board-displays/View A/view.xhtml"
  git commit -qam colleague; git push -q origin dev )
echo colleague-view >"$T/platform/b1/board-displays/View A/view.xhtml"
git worktree add -q .claude/worktrees/s4 -b worktree-s4
( cd .claude/worktrees/s4; echo s4-view >"boards/b1/board-displays/View A/view.xhtml"; git commit -qam s4 )
set +e; out=$("$TP" push s4 2>&1); rc=$?; set -e
check "behind: stops and says dev is behind origin" '[ $rc -eq 3 ] && grep -q "b1/View A — live = origin/dev, but your local dev is behind" <<<"$out"'
set +e; "$TP" push s4 >/dev/null 2>&1; rc=$?; set -e
check "a stopped push stays stopped on the next try (the conflict is remembered)" '[ $rc -eq 3 ]'
: >"$WEBOARD_LOG"
"$TP" push s4 --overwrite-live >/dev/null
check "--overwrite-live pushes the stream build anyway" '[ "$(cat "$WEBOARD_LOG")" = "View A=s4-view" ]'
: >"$WEBOARD_LOG"
"$TP" before s4 >/dev/null
check "before puts the colleague's live view back" '[ "$(cat "$WEBOARD_LOG")" = "View A=colleague-view" ]'
"$TP" release s4 >/dev/null
git worktree add -q .claude/worktrees/s5 -b worktree-s5
( cd .claude/worktrees/s5; echo s5-view >"boards/b1/board-displays/View A/view.xhtml"; git commit -qam s5 )
set +e; "$TP" push s5 >/dev/null 2>&1; rc=$?; set -e
check "behind, then dev pulled and merged: the push goes ahead" '[ $rc -eq 3 ] && git pull -q origin dev && ( cd .claude/worktrees/s5 && git merge -q -X ours dev -m m ) && "$TP" push s5 >/dev/null'

echo; [ $fails -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
