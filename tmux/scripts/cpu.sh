#!/usr/bin/env sh
case "${DOTFILES_TEST_OS:-$(uname -s)}" in
Darwin) top -l 1 -n 0 2>/dev/null | awk -F'[:,%]+' '/CPU usage/ { printf "CPU %.0f%%", $2 + $3 }' ;;
Linux)
  stat_file=${DOTFILES_CPU_STAT_FILE:-/proc/stat}
  awk '/^cpu / {
        total=$2+$3+$4+$5+$6+$7+$8+$9
        idle=$5+$6
        if (total) printf "CPU %.0f%%", 100*(total-idle)/total
      }' "$stat_file" 2>/dev/null || :
  ;;
esac
