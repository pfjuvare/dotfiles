#!/usr/bin/env bash
# gitlab-mr.sh — create / inspect GitLab merge requests via the REST API (v4). No glab needed.
#
# Usage (run inside the repo):
#   gitlab-mr.sh check                         verify token + resolve the project from the remote
#   gitlab-mr.sh existing <source> <target>    list open MRs for that branch pair
#   gitlab-mr.sh recent <source>               last 5 MRs from that branch (shows the usual target)
#   gitlab-mr.sh create --source <b> --target <b> --title <t> [--description-file <f>]
#                       [--draft] [--remove-source] [--dry-run]
#   gitlab-mr.sh status <iid>                  state + merge status of an MR
#   gitlab-mr.sh description <iid> [--section <heading>]
#                                              print the MR description (or one `## <heading>` section)
#   gitlab-mr.sh merge <iid>                   merge an MR (only when PJF has asked for that MR)
#   gitlab-mr.sh notify <iid> [--channel <c>] [--note <text>] [--dry-run]
#                                              post a review request card for the MR to a Teams channel
#
# Remote: `origin` (override with GITLAB_REMOTE). Host/project are derived from its URL
# (ssh://git@host:port/group/proj.git, git@host:group/proj.git, https://host/group/proj.git).
# Token: $GITLAB_TOKEN, else GITLAB_TOKEN=... in ~/.config/gitlab/<host>.env (chmod 600).
# Needs a personal access token with `api` scope: https://<host>/-/user_settings/personal_access_tokens
# Teams: TEAMS_WEBHOOK_URL=... in ~/.config/teams/<channel>.env (default channel: code-reviews), a Teams
# Workflows "Send webhook alerts to a channel" URL. Optional TEAMS_SIGNATURE=... (card footer; default
# "<git user.name first name>'s agent wrote this message").
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
[ -n "${GITLAB_TOKEN:-}" ] || die "no token. Create an api-scope PAT at https://$host/-/user_settings/personal_access_tokens and put GITLAB_TOKEN=<token> in $envfile (chmod 600)"

gl() { curl -sS --fail-with-body -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$@"; }

cmd=${1:-}; shift || true
case "$cmd" in
  check)
    user=$(gl "$api/user" | jq -r .username) || die "token rejected by $host"
    # Project: Read is optional (only gives the default branch); Merge Request: Read is required.
    proj=$(gl "$api/projects/$project" 2>/dev/null | jq -r '"\(.path_with_namespace) (default branch: \(.default_branch))"') \
      || proj="$path (default branch unknown — token lacks Project: Read)"
    gl -G "$api/projects/$project/merge_requests" --data-urlencode per_page=1 >/dev/null \
      || die "can't read merge requests on $path — token needs Merge Request: Read + Create"
    echo "host    $host"; echo "user    $user"; echo "project $proj"
    ;;
  existing)
    [ $# -eq 2 ] || die "usage: existing <source> <target>"
    gl -G "$api/projects/$project/merge_requests" --data-urlencode state=opened \
      --data-urlencode "source_branch=$1" --data-urlencode "target_branch=$2" \
      | jq -r '.[] | "!\(.iid)  \(.title)  \(.web_url)"'
    ;;
  recent)
    [ $# -eq 1 ] || die "usage: recent <source>"
    gl -G "$api/projects/$project/merge_requests" --data-urlencode state=all --data-urlencode per_page=5 \
      --data-urlencode "source_branch=$1" \
      | jq -r '.[] | "!\(.iid) \(.state) \(.source_branch)→\(.target_branch)  \(.title)"'
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
  status)
    [ $# -eq 1 ] || die "usage: status <iid>"
    gl "$api/projects/$project/merge_requests/$1" \
      | jq -r '"!\(.iid) \(.state) \(.detailed_merge_status) conflicts=\(.has_conflicts) \(.source_branch)→\(.target_branch)"'
    ;;
  description)
    iid="" section=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --section) section="$2"; shift 2 ;;
        -*) die "unknown flag $1" ;;
        *) iid="$1"; shift ;;
      esac
    done
    [ -n "$iid" ] || die "usage: description <iid> [--section <heading>]"
    desc=$(gl "$api/projects/$project/merge_requests/$iid" | jq -r '.description // ""')
    if [ -z "$section" ]; then printf '%s\n' "$desc"; exit 0; fi
    # body of `## <heading>` (case-insensitive) up to the next heading / Card: / footer; exit 1 if absent
    awk -v h="$section" 'BEGIN{h=tolower(h)}
      /^#+ /{ t=tolower($0); sub(/^#+ +/,"",t); sub(/ +$/,"",t); on=(t==h); found=found||on; next }
      /^(Card:|🤖)/{ on=0 }
      on { buf=buf $0 "\n"; if ($0 != "") { printf "%s", buf; buf="" } }
      END{ exit !found }' <<<"$desc"
    ;;
  merge)
    [ $# -eq 1 ] || die "usage: merge <iid>"
    gl -X PUT "$api/projects/$project/merge_requests/$1/merge" \
      | jq -r '"!\(.iid) \(.state): \(.merge_commit_sha // .squash_commit_sha // "-")  \(.web_url)"'
    ;;
  notify)
    iid="" channel=code-reviews note="" dry=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --channel) channel="$2"; shift 2 ;;
        --note) note="$2"; shift 2 ;;
        --dry-run) dry=1; shift ;;
        -*) die "unknown flag $1" ;;
        *) iid="$1"; shift ;;
      esac
    done
    [ -n "$iid" ] || die "usage: notify <iid> [--channel <c>] [--note <text>] [--dry-run]"
    teamsenv="$HOME/.config/teams/$channel.env"
    [ -f "$teamsenv" ] || die "no $teamsenv — put TEAMS_WEBHOOK_URL=<workflows url> in it (chmod 600)"
    hook=$(sed -n 's/^TEAMS_WEBHOOK_URL=//p' "$teamsenv" | tr -d '"'"'"'')
    [ -n "$hook" ] || die "TEAMS_WEBHOOK_URL not set in $teamsenv"
    sig=$(sed -n 's/^TEAMS_SIGNATURE=//p' "$teamsenv" | tr -d '"')
    [ -n "$sig" ] || sig="$(git config user.name | cut -d' ' -f1)'s agent wrote this message"
    card=$(gl "$api/projects/$project/merge_requests/$iid" | jq --arg path "$path" --arg note "$note" --arg sig "$sig" '{
      type: "message",
      attachments: [{
        contentType: "application/vnd.microsoft.card.adaptive",
        content: {
          "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
          type: "AdaptiveCard", version: "1.4", msteams: { width: "Full" },
          body: ([
            { type: "TextBlock", text: "Code review request", weight: "Bolder", size: "Medium" },
            { type: "TextBlock", text: "[!\(.iid) \(.title)](\(.web_url))", wrap: true },
            { type: "FactSet", facts: [
              { title: "Repo", value: ($path | split("/") | last) },
              { title: "Branch", value: "\(.source_branch) → \(.target_branch)" },
              { title: "Author", value: .author.name } ] }
          ] + (if $note == "" then [] else [{ type: "TextBlock", text: $note, wrap: true }] end) + [
            { type: "TextBlock", text: $sig, isSubtle: true, size: "Small", wrap: true }
          ]),
          actions: [{ type: "Action.OpenUrl", title: "Open MR", url: .web_url }]
        }
      }]
    }')
    if [ $dry -eq 1 ]; then echo "channel $channel"; echo "$card"; exit 0; fi
    curl -sS --fail-with-body -H 'Content-Type: application/json' -d "$card" "$hook" >/dev/null \
      || die "Teams webhook rejected the post"
    echo "!$iid posted to Teams ($channel)"
    ;;
  *) sed -n '2,22p' "$0"; exit 1 ;;
esac
