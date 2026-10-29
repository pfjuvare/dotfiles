#!/usr/bin/env bash
# test-push.test.sh — exercises test-push.sh against a throwaway repo with a fake `weboard` that records
# what would have been pushed (and which version). Never touches a real platform. Run: bash test-push.test.sh
set -euo pipefail

TP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-push.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# fake weboard: `weboard push <asset>` logs "<asset>=<first line of the asset's file>"
mkdir -p "$T/bin"
cat >"$T/bin/weboard" <<'EOF'
#!/usr/bin/env bash
[ "$1" = push ] || exit 1
f=$(ls -d board-*/"$2"/* 2>/dev/null | head -1)
echo "$2=$(head -1 "$f")" >>"$WEBOARD_LOG"
echo "$2 successfully pushed"
EOF
chmod +x "$T/bin/weboard"
export PATH="$T/bin:$PATH" WEBOARD_LOG="$T/log"

repo="$T/repo"; mkdir -p "$repo/boards/b1/board-displays/View A" "$repo/boards/b1/board-resources/Res"
cd "$repo"
git init -q -b dev
git config user.email t@t; git config user.name t
echo dev-view >"boards/b1/board-displays/View A/view.xhtml"
echo dev-res >"boards/b1/board-resources/Res/res.js"
mkdir -p "boards/b1/board-tables/ZTbl"; echo dev-tbl >"boards/b1/board-tables/ZTbl/config.json"
echo 'WE_URL=x' >boards/b1/.env; echo '.env' >.gitignore
git add -A; git commit -qm base
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

"$TP" push s1 >/dev/null
check "push: table first, then the stream build of both views" '[ "$(head -1 "$WEBOARD_LOG")" = "ZTbl=stream-tbl" ] && [ "$(last 2)" = "View A=stream-view View B=stream-new " ]'

: >"$WEBOARD_LOG"
out=$("$TP" before s1 --dry-run)
check "before --dry-run pushes nothing" '[ ! -s "$WEBOARD_LOG" ]'
check "before --dry-run lists the new view as having no before version" 'grep -q "no before version.*View B" <<<"$out"'

"$TP" before s1 >/dev/null
check "before: dev's table first, then dev's View A (View B has no before)" '[ "$(cat "$WEBOARD_LOG" | tr "\n" " ")" = "ZTbl=dev-tbl View A=dev-view " ]'
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
check "release --restore re-pushes dev's version, table first" '[ "$(cat "$WEBOARD_LOG" | tr "\n" " ")" = "ZTbl=dev-tbl View A=dev-view " ]'
check "release drops the claims" '[ ! -s .git/test-slots.tsv ]'

check "before refuses a stream with no claims" '! "$TP" before s1 >/dev/null 2>&1'

echo; [ $fails -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
