# AGENTS.md

## Linting and formatting

Hooks are configured in `.pre-commit-config.yaml` and run with
[prek](https://github.com/j178/prek):

```console
$ prek install          # install the git pre-commit hook (once)
$ prek run --all-files  # run every hook against the whole repo
$ prek autoupdate       # bump hook revisions
```

Shell scripts are checked with `shellcheck` and formatted with `shfmt`
(4-space indent, binary operators at the start of continuation lines,
indented `case` branches).

## Conventions

- Scripts live in `scripts/`, are `bash`, executable, and start with
  `set -euo pipefail`.
- Scripts that change anything on GitHub default to a dry run and require
  `--apply` to actually act.
- Document each script in `README.md`.
