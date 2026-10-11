#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
hooks_dir="$repo_root/scripts/hooks"

if [[ ! -x "$hooks_dir/pre-commit" ]]; then
  printf 'Expected executable pre-commit hook at %s\n' "$hooks_dir/pre-commit" >&2
  exit 1
fi

git -C "$repo_root" config --local core.hooksPath "$hooks_dir"
printf 'Installed repository-local Git hooks from %s\n' "$hooks_dir"
printf 'The brand identity gate will run before each commit.\n'
