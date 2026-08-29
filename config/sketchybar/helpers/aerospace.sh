#!/usr/bin/env bash

set -u

find_command() {
  local candidate

  for candidate in "/opt/homebrew/bin/$1" "/usr/local/bin/$1"; do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  command -v "$1" 2>/dev/null || return 1
}

action="${1:-}"
value="${2:-}"

case "${action}" in
  focus)
    aerospace_bin="$(find_command aerospace)" || exit 0
    [[ -n "${value}" ]] && "${aerospace_bin}" workspace "${value}"
    ;;
  query)
    aerospace_bin="$(find_command aerospace)" || exit 0
    "${aerospace_bin}" list-workspaces --focused
    ;;
  list)
    aerospace_bin="$(find_command aerospace)" || exit 0
    "${aerospace_bin}" list-workspaces --all
    ;;
  front-app)
    aerospace_bin="$(find_command aerospace)" || exit 0
    [[ -n "${value}" ]] || exit 0

    window_count="$("${aerospace_bin}" list-windows --workspace "${value}" --count 2>/dev/null)" || exit 0
    [[ "${window_count}" =~ ^[1-9][0-9]*$ ]] || exit 0

    focused_workspace="$("${aerospace_bin}" list-workspaces --focused 2>/dev/null)" || exit 0
    [[ "${focused_workspace}" == "${value}" ]] || exit 0
    "${aerospace_bin}" list-windows --focused --format '%{app-name}' 2>/dev/null \
      | /usr/bin/awk 'NF { print; exit }'
    ;;
  notify)
    sketchybar_bin="$(find_command sketchybar)" || exit 0
    if [[ -n "${value}" ]]; then
      "${sketchybar_bin}" --trigger aerospace_workspace_change "FOCUSED_WORKSPACE=${value}" || true
    fi
    ;;
esac
