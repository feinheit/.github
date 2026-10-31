# .github

Community health files and org-wide tooling for the
[feinheit](https://github.com/feinheit) GitHub organization. The org profile
lives in `profile/README.md`.

Scripts which settle repository settings and merge bot pull requests across
both the `feincms` and `feinheit` owners live in
[feincms/.github](https://github.com/feincms/.github)
(`normalize-repo-settings.sh`, `merge-bot-prs.sh`).

## Scripts

### `scripts/archive-inactive-repos.sh`

Archives repos without a push for 5 years (`YEARS`). Archiving only makes a
repo read-only and can be undone in its settings with one click.

Repos named after a website (`example.ch`, `example_ch`) whose site still
answers on that domain are reported as `UNCLEAR` and left alone, since we may
still host them. A redirect to another domain counts as moved on. Repos
listed in `KEEP` are never archived; pushing a commit has the same effect for
the next 5 years.

Inactivity is based on the last push to any branch. Imports reset it: the
repos moved over from `feinheit-archive` in February 2023 look active until
2028 although many of them weren't touched for much longer.

```console
$ ./scripts/archive-inactive-repos.sh          # preview only (default)
$ ./scripts/archive-inactive-repos.sh --apply  # actually archive
```

### `scripts/compare-repos.sh`

Checks that every branch and tag of one repo is contained in another, e.g.
before deleting a duplicate. Branches with commits missing in the target are
listed; with `--apply` they are pushed to the target as `archive/<branch>`
(missing tags under their own name) and the check runs again. Exits with 0
only if nothing is missing. It never deletes anything, delete the source
yourself once it passes.

```console
$ ./scripts/compare-repos.sh feinheit-archive/example feinheit/example          # preview only (default)
$ ./scripts/compare-repos.sh feinheit-archive/example feinheit/example --apply  # copy missing branches
```

### `scripts/audit-access.sh`

Read only. Lists the plan's seats, outside collaborators per repo (they take
paid seats on private repos), pending invitations and members without
two-factor authentication (needs an org owner).

```console
$ ./scripts/audit-access.sh
```

All scripts require the [`gh` CLI](https://cli.github.com/) (authenticated,
`repo` scope) and `jq`.
