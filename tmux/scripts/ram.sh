#!/usr/bin/env sh

total_gib=$(sysctl -n hw.memsize | awk '{ printf "%.0f", $1 / 1024 / 1024 / 1024 }')
used=$(top -l 1 -n 0 | awk '/PhysMem:/ { print $2 }')

if [ -n "$used" ] && [ -n "$total_gib" ]; then
  printf 'RAM %s/%sGiB' "$used" "$total_gib"
fi
