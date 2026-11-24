#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ZSH=$(command -v zsh)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
failures=0

# Run the real completion audit without inheriting the runner's site completions.
# Keep the standard helpers used by optional plugins installed by the host.
completions="$fixture/completions"
mkdir -m 700 "$completions"
"$ZSH" -f -c '
  for name in compinit compaudit compdump compinstall add-zsh-hook is-at-least; do
    files=(${^fpath}/$name(N.))
    (( $#files )) || { print -ru2 -- "Missing Zsh completion function: $name"; exit 1; }
    cp "$files[1]" "$1/$name" || exit 1
  done
' zsh "$completions"

stub() {
  local dir=$1 name=$2 args=$3
  mkdir -p "$dir"
  printf '#!/bin/sh\n[ "$*" = "%s" ] || { echo "unexpected %s arguments: $*" >&2; exit 1; }\nprintf "%%s\\n" "print -r -- %s"\n' \
    "$args" "$name" "$name" >"$dir/$name"
  chmod +x "$dir/$name"
}

run_case() {
  local name=$1 home=$2 expected=$3 status=0 utility
  mkdir -p "$home/path"
  for utility in ls mv rm; do
    ln -s "$(command -v "$utility")" "$home/path/$utility"
  done
  env -i HOME="$home" ZDOTDIR="$home" PATH="$home/path" LC_ALL=C \
    "$ZSH" -f -c 'fpath=("$2"); _compdir=""; source "$1" && [[ -s "$ZDOTDIR/.zcompdump" ]]' \
    zsh "$ROOT/zsh/.zshrc" "$completions" \
    >"$fixture/stdout" 2>"$fixture/stderr" || status=$?
  printf '%s' "$expected" >"$fixture/expected"
  if [[ "$status" != 0 || -s "$fixture/stderr" ]] || ! cmp -s "$fixture/expected" "$fixture/stdout"; then
    printf 'FAIL: %s (exit %s)\n' "$name" "$status" >&2
    diff -u "$fixture/expected" "$fixture/stdout" >&2 || true
    if [[ -s "$fixture/stderr" ]]; then
      while IFS= read -r line; do printf '%s\n' "$line" >&2; done <"$fixture/stderr"
    fi
    failures=$((failures + 1))
  fi
}

home="$fixture/local"
stub "$home/.local/bin" starship 'init zsh'
stub "$home/.local/share/fnm" fnm 'env --use-on-cd --shell zsh'
run_case 'tools in user-local directories' "$home" $'fnm\nstarship\n'

home="$fixture/cargo"
stub "$home/.local/bin" fnm 'env --use-on-cd --shell zsh'
run_case 'fnm in the Cargo install directory' "$home" $'fnm\n'

home="$fixture/path"
stub "$home/path" starship 'init zsh'
stub "$home/path" fnm 'env --use-on-cd --shell zsh'
run_case 'tools already on PATH initialize once' "$home" $'fnm\nstarship\n'

home="$fixture/missing"
mkdir -p "$home"
run_case 'missing optional tools do not emit errors' "$home" ''

[[ "$failures" == 0 ]] || exit 1
printf 'Zsh startup tests passed\n'
