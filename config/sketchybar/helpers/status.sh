#!/usr/bin/env bash

set -u

clamp_percentage() {
  /usr/bin/awk '{ value = int($1 + 0.5); if (value < 0) value = 0; if (value > 100) value = 100; print value }'
}

case "${1:-}" in
  volume)
    if [[ -x /usr/bin/osascript ]]; then
      /usr/bin/osascript \
        -e 'set currentSettings to get volume settings' \
        -e 'return (output volume of currentSettings as text) & "," & (output muted of currentSettings as text)' \
        2>/dev/null
    fi
    ;;
  volume-toggle)
    if [[ -x /usr/bin/osascript ]]; then
      /usr/bin/osascript \
        -e 'set currentSettings to get volume settings' \
        -e 'set volume output muted not (output muted of currentSettings)' \
        -e 'set updatedSettings to get volume settings' \
        -e 'return (output volume of updatedSettings as text) & "," & (output muted of updatedSettings as text)' \
        2>/dev/null
    fi
    ;;
  volume-step)
    if [[ -x /usr/bin/osascript ]]; then
      case "${2:-}" in
        up)
          /usr/bin/osascript \
            -e 'set currentSettings to get volume settings' \
            -e 'set targetVolume to (output volume of currentSettings) + 5' \
            -e 'if targetVolume > 100 then set targetVolume to 100' \
            -e 'set volume output volume targetVolume' \
            -e 'set updatedSettings to get volume settings' \
            -e 'return (output volume of updatedSettings as text) & "," & (output muted of updatedSettings as text)' \
            2>/dev/null
          ;;
        down)
          /usr/bin/osascript \
            -e 'set currentSettings to get volume settings' \
            -e 'set targetVolume to (output volume of currentSettings) - 5' \
            -e 'if targetVolume < 0 then set targetVolume to 0' \
            -e 'set volume output volume targetVolume' \
            -e 'set updatedSettings to get volume settings' \
            -e 'return (output volume of updatedSettings as text) & "," & (output muted of updatedSettings as text)' \
            2>/dev/null
          ;;
      esac
    fi
    ;;
  battery)
    if [[ -x /usr/bin/pmset ]]; then
      /usr/bin/pmset -g batt 2>/dev/null
    fi
    ;;
  wifi)
    if [[ -x /usr/sbin/networksetup && -x /usr/sbin/scutil && -x /sbin/ifconfig ]]; then
      wifi_device="$(
        /usr/sbin/networksetup -listallhardwareports 2>/dev/null \
          | /usr/bin/awk '/Hardware Port: (Wi-Fi|AirPort)/ { getline; print $2; exit }'
      )"
      if [[ -n "${wifi_device}" ]] \
        && /sbin/ifconfig "${wifi_device}" 2>/dev/null \
          | /usr/bin/awk '/status: active/ { active = 1 } /inet / { address = 1 } END { exit !(active && address) }' \
        && [[ "$(/usr/sbin/scutil -r 1.1.1.1 2>/dev/null | /usr/bin/awk 'NR == 1 { print; exit }')" == "Reachable" ]]; then
        printf 'connected\n'
      else
        printf 'disconnected\n'
      fi
    fi
    ;;
  cpu)
    if [[ -x /usr/bin/top && -x /usr/bin/awk ]]; then
      LC_ALL=C /usr/bin/top -l 1 -n 0 -stats cpu 2>/dev/null \
        | /usr/bin/awk '/CPU usage:/ { gsub(/%/, "", $3); gsub(/%/, "", $5); print $3 + $5; exit }' \
        | clamp_percentage
    fi
    ;;
  ram)
    if [[ -x /usr/bin/vm_stat && -x /usr/sbin/sysctl && -x /usr/bin/awk ]]; then
      total_bytes="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || true)"
      if [[ "${total_bytes}" =~ ^[0-9]+$ ]] && [[ "${total_bytes}" -gt 0 ]]; then
        /usr/bin/vm_stat 2>/dev/null \
          | /usr/bin/awk -v total="${total_bytes}" '
              NR == 1 { page_size = $8 }
              /Pages active:/ { gsub(/\./, "", $3); active = $3 }
              /Pages wired down:/ { gsub(/\./, "", $4); wired = $4 }
              /Pages occupied by compressor:/ { gsub(/\./, "", $5); compressed = $5 }
              END { if (page_size > 0) print 100 * (active + wired + compressed) * page_size / total }
            ' \
          | clamp_percentage
      fi
    fi
    ;;
  disk)
    if [[ -x /usr/sbin/diskutil && -x /usr/bin/awk ]]; then
      /usr/sbin/diskutil info / 2>/dev/null \
        | /usr/bin/awk '
            /Container Total Space:/ { gsub(/[()]/, "", $6); total = $6 }
            /Container Free Space:/ { gsub(/[()]/, "", $6); free = $6 }
            END { if (total > 0) print 100 * (total - free) / total }
          ' \
        | clamp_percentage
    elif [[ -x /bin/df && -x /usr/bin/awk ]]; then
      /bin/df -Pk / 2>/dev/null \
        | /usr/bin/awk 'NR == 2 { gsub(/%/, "", $5); print $5 }' \
        | clamp_percentage
    fi
    ;;
esac
