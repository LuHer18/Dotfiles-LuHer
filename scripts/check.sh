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
run_check "verify executable bit config/sketchybar/sketchybarrc" \
  assert_executable "${REPO_DIR}/config/sketchybar/sketchybarrc"

for helper_path in "${REPO_DIR}/config/sketchybar/helpers/"*.sh; do
  run_check "verify executable bit ${helper_path##${REPO_DIR}/}" assert_executable "${helper_path}"
done

run_check "verify executable bit config/sketchybar/helpers/media_watcher.py" \
  assert_executable "${REPO_DIR}/config/sketchybar/helpers/media_watcher.py"

for script_path in "${REPO_DIR}/tmux/scripts/"*.sh; do
  run_check "verify executable bit ${script_path##${REPO_DIR}/}" assert_executable "${script_path}"
done

if command -v bash >/dev/null 2>&1; then
  run_check "bash -n install.sh" bash -n "${REPO_DIR}/install.sh"
  run_check "bash -n scripts/check.sh" bash -n "${REPO_DIR}/scripts/check.sh"
  run_check "bash -n config/sketchybar/helpers/aerospace.sh" \
    bash -n "${REPO_DIR}/config/sketchybar/helpers/aerospace.sh"
  run_check "bash -n config/sketchybar/helpers/app_icon.sh" \
    bash -n "${REPO_DIR}/config/sketchybar/helpers/app_icon.sh"
  run_check "bash -n config/sketchybar/helpers/status.sh" \
    bash -n "${REPO_DIR}/config/sketchybar/helpers/status.sh"

  app_font="${HOME}/Library/Fonts/sketchybar-app-font.ttf"
  app_icon_map="${XDG_DATA_HOME:-${HOME}/.local/share}/sketchybar-app-font/icon_map.sh"
  if [[ ! -r "${app_font}" ]]; then
    log "FAIL missing SketchyBar app font: ${app_font}"
    exit 1
  fi
  run_check "verify executable SketchyBar application map" assert_executable "${app_icon_map}"

  unknown_icon="$("${REPO_DIR}/config/sketchybar/helpers/app_icon.sh" "Dotfiles Unknown App")"
  if [[ "${unknown_icon}" != ":default:" ]]; then
    log "FAIL unknown application did not use :default: fallback"
    exit 1
  fi
  log "verified unknown application fallback"
fi

if command -v python3 >/dev/null 2>&1; then
  run_check "parse dotfiles.json" python3 -m json.tool "${REPO_DIR}/dotfiles.json" >/dev/null
  run_check "parse config/sketchybar/helpers/media_watcher.py" \
    python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))' \
    "${REPO_DIR}/config/sketchybar/helpers/media_watcher.py"
else
  log "SKIP JSON parse (python3 not available)"
fi

if command -v luac >/dev/null 2>&1; then
  for lua_path in \
    "${REPO_DIR}/config/sketchybar/sketchybarrc" \
    "${REPO_DIR}/config/sketchybar/"*.lua \
    "${REPO_DIR}/config/sketchybar/items/"*.lua; do
    run_check "luac -p ${lua_path##${REPO_DIR}/}" luac -p "${lua_path}"
  done
else
  log "SKIP Lua syntax checks (luac not available)"
fi

if command -v lua >/dev/null 2>&1; then
  for lua_path in \
    "${REPO_DIR}/config/sketchybar/sketchybarrc" \
    "${REPO_DIR}/config/sketchybar/"*.lua \
    "${REPO_DIR}/config/sketchybar/items/"*.lua; do
    run_check "Lua loadfile ${lua_path##${REPO_DIR}/}" \
      env LUA_CHECK_PATH="${lua_path}" lua -e 'assert(loadfile(os.getenv("LUA_CHECK_PATH")))'
  done
else
  log "SKIP Lua loadfile checks (lua not available)"
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
      "${REPO_DIR}/config/sketchybar/helpers/"*.sh \
      "${REPO_DIR}/tmux/scripts/"*.sh
else
  log "SKIP shellcheck (not available)"
fi

log "All requested checks finished"
