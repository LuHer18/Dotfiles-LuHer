#!/usr/bin/env bash

set -u

app_name="${1:-}"
data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
icon_map="${SKETCHYBAR_APP_FONT_MAP:-${data_home}/sketchybar-app-font/icon_map.sh}"
fallback=":default:"
icon=""

if [[ -x "${icon_map}" ]]; then
  icon="$("${icon_map}" "${app_name}" 2>/dev/null)"
  icon="${icon%% *}"
fi

if [[ ! "${icon}" =~ ^:[[:alnum:]_+-]+:$ ]]; then
  icon="${fallback}"
fi

printf '%s\n' "${icon}"
