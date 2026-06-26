#!/usr/bin/env sh

page_size=$(vm_stat | awk '/page size of/ { gsub(/\./, "", $8); print $8 }')
total_gib=$(sysctl -n hw.memsize | awk '{ printf "%.0f", $1 / 1024 / 1024 / 1024 }')

used_gib=$(
  vm_stat | awk -v page_size="$page_size" '
    /Pages active/ { gsub(/\./, "", $3); active = $3 }
    /Pages wired down/ { gsub(/\./, "", $4); wired = $4 }
    /Pages occupied by compressor/ { gsub(/\./, "", $5); compressed = $5 }
    END {
      used_bytes = (active + wired + compressed) * page_size
      printf "%.0f", used_bytes / 1024 / 1024 / 1024
    }
  '
)

if [ -n "$used_gib" ] && [ -n "$total_gib" ]; then
  printf 'RAM %s/%sGiB' "$used_gib" "$total_gib"
fi
