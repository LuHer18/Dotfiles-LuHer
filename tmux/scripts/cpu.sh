#!/usr/bin/env sh

top -l 1 -n 0 | awk -F'[:,%]+' '/CPU usage/ {
  user = $2 + 0
  sys = $3 + 0
  printf "CPU %.0f%%", user + sys
}'
