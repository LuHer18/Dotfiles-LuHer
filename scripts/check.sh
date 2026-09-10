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
  run_check "bash -n scripts/install-apps.sh" bash -n "${REPO_DIR}/scripts/install-apps.sh"
  run_check "bash -n tests/test_install_apps.sh" bash -n "${REPO_DIR}/tests/test_install_apps.sh"
  run_check "bash -n scripts/setup-pi.sh" bash -n "${REPO_DIR}/scripts/setup-pi.sh"
  run_check "bash -n dotfiles" bash -n "${REPO_DIR}/dotfiles"
  run_check "bash -n tests/test_cli.sh" bash -n "${REPO_DIR}/tests/test_cli.sh"
  run_check "bash -n tests/test_setup_pi.sh" bash -n "${REPO_DIR}/tests/test_setup_pi.sh"
fi

if command -v python3 >/dev/null 2>&1; then
  run_check "parse dotfiles.json" python3 -m json.tool "${REPO_DIR}/dotfiles.json" >/dev/null
else
  log "SKIP JSON parse (python3 not available)"
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
  run_check "shellcheck shell helpers" \
    shellcheck \
    "${REPO_DIR}/install.sh" \
    "${REPO_DIR}/scripts/check.sh" \
    "${REPO_DIR}/tmux/scripts/"*.sh
else
  log "SKIP shellcheck (not available)"
fi

if [[ "${DOTFILES_SKIP_SETUP_PI_TEST:-0}" != 1 ]] && [[ -x "${REPO_DIR}/tests/test_setup_pi.sh" ]]; then
  run_check "Pi setup tests" bash "${REPO_DIR}/tests/test_setup_pi.sh"
fi

if [[ -x "${REPO_DIR}/tests/test_cli.sh" ]]; then
  run_check "CLI tests" bash "${REPO_DIR}/tests/test_cli.sh"
fi
if [[ -x "${REPO_DIR}/tests/test_install_apps.sh" ]]; then
  run_check "application tests" bash "${REPO_DIR}/tests/test_install_apps.sh"
fi

if [[ "${DOTFILES_SKIP_PORTABILITY_TEST:-0}" != 1 ]] && [[ -x "${REPO_DIR}/tests/test_portability.sh" ]]; then
  run_check "portability tests" bash "${REPO_DIR}/tests/test_portability.sh"
fi

log "All requested checks finished"
