#!/usr/bin/env bash
# Check that every branch and tag of SOURCE is contained in TARGET, e.g.
# before deleting a duplicate repo. Lists the branches with commits missing in
# TARGET. With --apply, pushes them to TARGET as "archive/<branch>" (and
# missing tags under their own name), then checks again.
#
# Exits with 0 if nothing is missing (anymore), 1 otherwise. Never deletes
# anything.
#
# Usage:
#   ./scripts/compare-repos.sh feinheit-archive/example feinheit/example
#   ./scripts/compare-repos.sh feinheit-archive/example feinheit/example --apply
#
# Requires: git with SSH access to both repos

set -euo pipefail

if [[ $# -lt 2 ]]; then
    sed -n '2,15p' "$0"
    exit 2
fi

SOURCE="$1"
TARGET="$2"
DRY_RUN=1
if [[ "${3:-}" == "--apply" ]]; then
    DRY_RUN=0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init -q --bare "$tmp"

fetch() {
    git -C "$tmp" fetch -q --prune "git@github.com:${SOURCE}.git" \
        '+refs/heads/*:refs/source/heads/*' '+refs/tags/*:refs/source/tags/*'
    git -C "$tmp" fetch -q --prune "git@github.com:${TARGET}.git" \
        '+refs/heads/*:refs/target/heads/*' '+refs/tags/*:refs/target/tags/*'
}

# Prints "<ref> <number of commits missing in TARGET>" for every incomplete
# ref of SOURCE.
missing() {
    local target_tips ref count
    mapfile -t target_tips < <(git -C "$tmp" for-each-ref --format='%(objectname)' refs/target/)
    git -C "$tmp" for-each-ref --format='%(refname)' refs/source/ | while read -r ref; do
        count=$(git -C "$tmp" rev-list --count "$ref" --not "${target_tips[@]}" --)
        if [[ "$count" != "0" ]]; then
            echo "$ref $count"
        fi
    done
}

fetch
report=$(missing)

if [[ -z "$report" ]]; then
    echo "OK       everything of ${SOURCE} is contained in ${TARGET}"
    exit 0
fi

refspecs=()
while read -r ref count; do
    case "$ref" in
        refs/source/heads/*)
            branch="${ref#refs/source/heads/}"
            dest="refs/heads/archive/${branch}"
            ;;
        refs/source/tags/*)
            dest="refs/tags/${ref#refs/source/tags/}"
            ;;
    esac
    tip=$(git -C "$tmp" log -1 --format='%cs %s' "$ref")
    if [[ -n "$(git -C "$tmp" for-each-ref "refs/target/${dest#refs/}")" ]]; then
        echo "CONFLICT ${ref#refs/source/}: ${count} commits missing, ${dest#refs/} exists in ${TARGET} (tip ${tip})"
        continue
    fi
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "MISSING  ${ref#refs/source/}: ${count} commits, would push as ${dest#refs/} (tip ${tip})"
    else
        echo "PUSHING  ${ref#refs/source/}: ${count} commits as ${dest#refs/} (tip ${tip})"
    fi
    refspecs+=("${ref}:${dest}")
done <<<"$report"

if [[ "$DRY_RUN" == "1" || "${#refspecs[@]}" -eq 0 ]]; then
    exit 1
fi

git -C "$tmp" push -q "git@github.com:${TARGET}.git" "${refspecs[@]}"
fetch
if [[ -n "$(missing)" ]]; then
    echo "INCOMPLETE ${TARGET} still lacks commits of ${SOURCE}"
    exit 1
fi
echo "OK       everything of ${SOURCE} is now contained in ${TARGET}"
