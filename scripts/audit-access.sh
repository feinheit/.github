#!/usr/bin/env bash
# Show who has access to the feinheit org's repos besides its members: outside
# collaborators (they take paid seats on private repos), pending invitations,
# and members without two-factor authentication. Read only.
#
# Usage:
#   ./scripts/audit-access.sh
#
# Requires: gh (authenticated with repo and read:org scopes, org owner for the
# two-factor check), jq

set -euo pipefail

ORG="feinheit"

gh api "orgs/${ORG}" --jq '"Plan: \(.plan.name), seats: \(.plan.filled_seats) of \(.plan.seats) filled"'

echo
echo "Outside collaborators:"
gh repo list "$ORG" --limit 1000 --no-archived --json name --jq '.[].name' \
    | sort \
    | while read -r name; do
        gh api --paginate "repos/${ORG}/${name}/collaborators?affiliation=outside" \
            --jq ".[] | \"  \(.login)\t${name}\t\(.role_name)\""
    done \
    | sort \
    | column -t -s $'\t'

echo
echo "Pending invitations:"
gh api --paginate "orgs/${ORG}/invitations" \
    --jq '.[] | "  \(.login // .email)\t\(.role)\tinvited \(.created_at[:10]) by \(.inviter.login)"' \
    | column -t -s $'\t'

echo
echo "Members without two-factor authentication:"
gh api --paginate "orgs/${ORG}/members?filter=2fa_disabled" --jq '.[] | "  \(.login)"'
