#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Checks for changes.
if [[ -n "$(git status --porcelain)" ]]; then

  # Commits changes.
  git add key image
  git commit -m "Updates image definitions"

  # Pushes changes. Rebases, waits and
  # retries three times on conflict.
  for _ in 1 2 3; do
    if git push; then break; fi
    git pull --rebase origin main
    sleep 3
  done
fi
