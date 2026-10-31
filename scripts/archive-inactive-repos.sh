#!/usr/bin/env bash
# Archive repos of the feinheit org without any activity for a number of
# years. Repos named after a website which still answers on that domain are
# left alone: we may still host them, even if nobody touched the code.
#
# Usage:
#   ./scripts/archive-inactive-repos.sh          # dry run: print what would be archived
#   ./scripts/archive-inactive-repos.sh --apply  # actually archive the repos
#
# Requires: gh (authenticated with repo scope, admin on the repos), jq, curl

set -euo pipefail

DRY_RUN=1
if [[ "${1:-}" == "--apply" ]]; then
    DRY_RUN=0
fi

ORG="feinheit"
YEARS=5

# Repos which should never be archived automatically even though they are
# inactive, e.g. sites we still host. Alternatively, push a commit.
KEEP=()

cutoff=$(date -u -d "-${YEARS} years" +%Y-%m-%dT%H:%M:%SZ)

# Repo names like "example.ch" or "example_ch" are sites. Prints the domain or
# nothing.
domain_of() {
    local name="$1"
    name=$(echo "$name" | sed -E 's/_(ch|com|de|net|org|li|at|swiss|biz)$/.\1/')
    if [[ "$name" =~ ^[a-z0-9-]+(\.[a-z0-9-]+)*\.(ch|com|de|net|org|li|at|swiss|biz)$ ]]; then
        echo "$name"
    fi
}

# Prints the host the site ends up on after following redirects, or nothing
# if it doesn't answer.
final_host() {
    local url
    url=$(curl -s -o /dev/null -L -m 10 -w '%{http_code} %{url_effective}' "https://$1" || true)
    if [[ "$url" =~ ^[23][0-9][0-9]\ https?://([^/:]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

gh repo list "$ORG" --limit 1000 --no-archived --json name,pushedAt,createdAt \
    | jq -r --arg cutoff "$cutoff" '
        .[]
        | (.pushedAt // .createdAt) as $last
        | select($last < $cutoff)
        | [.name, $last[:10]] | @tsv' \
    | sort \
    | while IFS=$'\t' read -r name last; do
        repo="${ORG}/${name}"

        if [[ " ${KEEP[*]} " == *" ${name} "* ]]; then
            echo "KEEP          ${repo}  (last push ${last}, listed in KEEP)"
            continue
        fi

        domain=$(domain_of "$name")
        if [[ -n "$domain" ]]; then
            host=$(final_host "$domain")
            # A redirect to another domain means the site has moved on.
            if [[ -n "$host" && "${host#www.}" == "${domain#www.}" ]]; then
                echo "UNCLEAR       ${repo}  (last push ${last}, https://${domain} still answers)"
                continue
            fi
        fi

        if [[ "$DRY_RUN" == "1" ]]; then
            echo "WOULD ARCHIVE ${repo}  (last push ${last})"
        elif gh api --method PATCH "repos/${repo}" -F archived=true >/dev/null; then
            echo "ARCHIVED      ${repo}  (last push ${last})"
        else
            echo "FAILED        ${repo}"
        fi
    done
