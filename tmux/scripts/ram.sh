#!/usr/bin/env sh
case "${DOTFILES_TEST_OS:-$(uname -s)}" in
Darwin)
  vm_stats=$(vm_stat 2>/dev/null) || vm_stats=
  page_size=$(printf '%s\n' "$vm_stats" | awk '
          /page size of/ {
            for (i = NF; i > 0; i--) {
              value = $i
              gsub(/\./, "", value)
              if (value ~ /^[0-9]+$/) {
                print value
                exit
              }
            }
          }')
  total=$(sysctl -n hw.memsize 2>/dev/null || :)
  used=$(printf '%s\n' "$vm_stats" | awk -v p="$page_size" \
    '/Pages active|Pages wired down|Pages occupied by compressor/ {
            value = ""
            for (i = NF; i > 0; i--) {
              candidate = $i
              gsub(/\./, "", candidate)
              if (candidate ~ /^[0-9]+$/) {
                value = candidate
                break
              }
            }
            if (value != "") sum += value
          }
          END { if (p != "" && sum != "") printf "%.0f", sum * p }')
  if [ -n "$total" ] && [ -n "$used" ]; then
    awk -v u="$used" -v t="$total" \
      'BEGIN { if (u >= 0 && t > 0) printf "RAM %.0f/%.0fGiB",u/1073741824,t/1073741824 }'
  fi
  ;;
Linux)
  meminfo_file=${DOTFILES_MEMINFO_FILE:-/proc/meminfo}
  awk '/MemTotal:/ { total=$2 } /MemAvailable:/ { available=$2 }
        END {
          if (total && available) {
            printf "RAM %.0f/%.0fGiB", (total-available)/1048576, total/1048576
          }
        }' "$meminfo_file" 2>/dev/null || :
  ;;
esac
