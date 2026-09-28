#!/usr/bin/env bash
# gitlab-mr.sh — create / inspect GitLab merge requests via the REST API (v4). No glab needed.
#
# Usage (run inside the repo):
#   gitlab-mr.sh check                         verify token + resolve the project from the remote
#   gitlab-mr.sh existing <source> <target>    list open MRs for that branch pair
#   gitlab-mr.sh create --source <b> --target <b> --title <t> [--description-file <f>]
#                       [--draft] [--remove-source] [--dry-run]
#
# Remote: `origin` (override with GITLAB_REMOTE). Host/project are derived from its URL
# (ssh://git@host:port/group/proj.git, git@host:group/proj.git, https://host/group/proj.git).
# Token: $GITLAB_TOKEN, else GITLAB_TOKEN=... in ~/.config/gitlab/<host>.env (chmod 600),
# else the <host> _authToken in ~/.npmrc.
# Needs a personal access token with `api` scope: https://<host>/-/user_settings/personal_access_tokens
set -euo pipefail

die() { echo "gitlab-mr: $*" >&2; exit 1; }
command -v jq >/dev/null || die "jq required"

remote=${GITLAB_REMOTE:-origin}
url=$(git remote get-url "$remote") || die "no remote '$remote'"
case "$url" in
  ssh://*) rest=${url#ssh://}; rest=${rest#*@}; host=${rest%%/*}; host=${host%%:*}; path=${rest#*/} ;;
  https://*|http://*) rest=${url#*://}; rest=${rest#*@}; host=${rest%%/*}; path=${rest#*/} ;;
  *@*:*) rest=${url#*@}; host=${rest%%:*}; path=${rest#*:} ;;
  *) die "can't parse remote url: $url" ;;
esac
path=${path%.git}
project=$(jq -rn --arg p "$path" '$p|@uri')
api="https://$host/api/v4"

envfile="$HOME/.config/gitlab/$host.env"
if [ -z "${GITLAB_TOKEN:-}" ] && [ -f "$envfile" ]; then
  GITLAB_TOKEN=$(sed -n 's/^GITLAB_TOKEN=//p' "$envfile" | tr -d '"'"'"'')
fi
# Fallback: the npm registry token for this host in ~/.npmrc (needs api scope).
if [ -z "${GITLAB_TOKEN:-}" ] && [ -f "$HOME/.npmrc" ]; then
  GITLAB_TOKEN=$(sed -n "s#^//$host/.*:_authToken=##p" "$HOME/.npmrc" | head -1)
fi
[ -n "${GITLAB_TOKEN:-}" ] || die "no token. Create an api-scope PAT at https://$host/-/user_settings/personal_access_tokens and put GITLAB_TOKEN=<token> in $envfile (chmod 600)"

gl() { curl -sS --fail-with-body -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$@"; }

cmd=${1:-}; shift || true
case "$cmd" in
  check)
    user=$(gl "$api/user" | jq -r .username) || die "token rejected by $host"
    proj=$(gl "$api/projects/$project" | jq -r '"\(.path_with_namespace) (default branch: \(.default_branch))"') \
      || die "project $path not accessible"
    echo "host    $host"; echo "user    $user"; echo "project $proj"
    ;;
  existing)
    [ $# -eq 2 ] || die "usage: existing <source> <target>"
    gl -G "$api/projects/$project/merge_requests" --data-urlencode state=opened \
      --data-urlencode "source_branch=$1" --data-urlencode "target_branch=$2" \
      | jq -r '.[] | "!\(.iid)  \(.title)  \(.web_url)"'
    ;;
  create)
    src="" tgt="" title="" descfile="" draft=0 rmsrc=0 dry=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --source) src="$2"; shift 2 ;;
        --target) tgt="$2"; shift 2 ;;
        --title) title="$2"; shift 2 ;;
        --description-file) descfile="$2"; shift 2 ;;
        --draft) draft=1; shift ;;
        --remove-source) rmsrc=1; shift ;;
        --dry-run) dry=1; shift ;;
        *) die "unknown flag $1" ;;
      esac
    done
    [ -n "$src" ] && [ -n "$tgt" ] && [ -n "$title" ] || die "--source, --target, --title required"
    [ -z "$descfile" ] || [ -f "$descfile" ] || die "description file not found: $descfile"
    git ls-remote --exit-code --heads "$remote" "$src" >/dev/null \
      || die "source branch '$src' is not on $remote — push it first"
    [ $draft -eq 1 ] && title="Draft: $title"
    desc=""; [ -n "$descfile" ] && desc=$(cat "$descfile")
    if [ $dry -eq 1 ]; then
      printf 'project %s\nsource  %s\ntarget  %s\ntitle   %s\nremove source: %s\n--- description\n%s\n' \
        "$path" "$src" "$tgt" "$title" "$rmsrc" "$desc"
      exit 0
    fi
    gl -X POST "$api/projects/$project/merge_requests" \
      --data-urlencode "source_branch=$src" --data-urlencode "target_branch=$tgt" \
      --data-urlencode "title=$title" --data-urlencode "description=$desc" \
      --data-urlencode "remove_source_branch=$([ $rmsrc -eq 1 ] && echo true || echo false)" \
      | jq -r '"!\(.iid) created: \(.web_url)"'
    ;;
  *) sed -n '2,14p' "$0"; exit 1 ;;
esac
