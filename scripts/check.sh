#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_SOCKET="dotfiles-luher-check"

log() {
  printf '[check] %s\n' "$1"
}

run_check() {
  log "$1"
  shift
  "$@"
}

assert_executable() {
  local path="$1"

  if [[ ! -x "${path}" ]]; then
    log "FAIL missing executable bit: ${path}"
    exit 1
  fi
}

run_check "verify executable bits" assert_executable "${REPO_DIR}/scripts/check.sh"

for script_path in "${REPO_DIR}/tmux/scripts/"*.sh; do
  run_check "verify executable bit ${script_path##${REPO_DIR}/}" assert_executable "${script_path}"
done

if command -v bash >/dev/null 2>&1; then
  run_check "bash -n install.sh" bash -n "${REPO_DIR}/install.sh"
  run_check "bash -n scripts/check.sh" bash -n "${REPO_DIR}/scripts/check.sh"
fi

if command -v zsh >/dev/null 2>&1; then
  run_check "zsh -n zsh/.zshrc" zsh -n "${REPO_DIR}/zsh/.zshrc"
else
  log "SKIP zsh syntax check (zsh not available)"
fi

if command -v tmux >/dev/null 2>&1; then
  log "tmux isolated config parse"
  tmux -L "${TMUX_SOCKET}" -f "${REPO_DIR}/tmux/.tmux.conf" start-server
  tmux -L "${TMUX_SOCKET}" kill-server >/dev/null 2>&1 || true
else
  log "SKIP tmux config parse (tmux not available)"
fi

if command -v shellcheck >/dev/null 2>&1; then
  run_check "shellcheck install.sh scripts/check.sh tmux/scripts/*.sh" \
    shellcheck \
      "${REPO_DIR}/install.sh" \
      "${REPO_DIR}/scripts/check.sh" \
      "${REPO_DIR}/tmux/scripts/"*.sh
else
  log "SKIP shellcheck (not available)"
fi

log "All requested checks finished"
