#!/usr/bin/env sh

path="$1"

[ -n "$path" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0

branch=$(git -C "$path" branch --show-current 2>/dev/null)

if [ -n "$branch" ]; then
  printf ' %s' "$branch"
fi
