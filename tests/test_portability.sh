#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}
assert_eq() { [[ "$1" == "$2" ]] || fail "$3 (got: $1, expected: $2)"; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "expected $2"; }

run_install() {
  local home=$1
  shift
  HOME="$home" DOTFILES_TEST_OS="${DOTFILES_TEST_OS:-Linux}" \
    bash "$ROOT/install.sh" --dry-run "$@"
}

output=$(run_install "$(mktemp -d)" --multiplexer tmux)
assert_contains "$output" 'Linux detected'
assert_contains "$output" 'tmux/.tmux.conf'
[[ "$output" != *'herdr/config.toml'* ]] || fail 'tmux selection included Herdr'
[[ "$output" != *'aerospace'* ]] || fail 'Linux included Aerospace'

output=$(run_install "$(mktemp -d)" --multiplexer herdr)
assert_contains "$output" 'herdr/config.toml'
[[ "$output" != *'tmux/.tmux.conf'* ]] || fail 'Herdr selection included tmux'

home=$(mktemp -d)
output=$(run_install "$home" --multiplexer both)
[[ -z "$(find "$home" -mindepth 1 -print -quit)" ]] || fail 'dry-run mutated HOME'

if HOME="$(mktemp -d)" DOTFILES_TEST_OS=Plan9 bash "$ROOT/install.sh" --dry-run; then
  fail 'unsupported OS accepted'
fi

fixture=$(mktemp -d)
printf 'cpu 100 50 25 200 25 10 10 20 999 999\n' >"$fixture/stat"
assert_eq "$(DOTFILES_CPU_STAT_FILE="$fixture/stat" DOTFILES_TEST_OS=Linux sh "$ROOT/tmux/scripts/cpu.sh")" \
  'CPU 49%' 'Linux CPU includes steal and excludes guest counters'
printf 'MemTotal:       4194304 kB\nMemAvailable:   2097152 kB\n' >"$fixture/meminfo"
assert_eq "$(DOTFILES_MEMINFO_FILE="$fixture/meminfo" DOTFILES_TEST_OS=Linux sh "$ROOT/tmux/scripts/ram.sh")" \
  'RAM 2/4GiB' 'Linux RAM fixture'
: >"$fixture/empty"
assert_eq "$(DOTFILES_CPU_STAT_FILE="$fixture/empty" DOTFILES_TEST_OS=Linux sh "$ROOT/tmux/scripts/cpu.sh")" '' 'CPU unavailable fallback'
assert_eq "$(DOTFILES_MEMINFO_FILE="$fixture/empty" DOTFILES_TEST_OS=Linux sh "$ROOT/tmux/scripts/ram.sh")" '' 'RAM unavailable fallback'

mkdir -p "$fixture/bin"
cat >"$fixture/bin/top" <<'EOF'
#!/bin/sh
printf 'CPU usage: 12.5%%,7.5%%,80%%\n'
EOF
cat >"$fixture/bin/vm_stat" <<'EOF'
#!/bin/sh
printf 'Mach Virtual Memory Statistics: (page size of 4096 bytes)\nPages active: 262144.\nPages wired down: 262144.\nPages occupied by compressor: 262144.\n'
EOF
cat >"$fixture/bin/sysctl" <<'EOF'
#!/bin/sh
printf '8589934592\n'
EOF
chmod +x "$fixture/bin"/*
assert_eq "$(PATH="$fixture/bin:/usr/bin:/bin" DOTFILES_TEST_OS=Darwin sh "$ROOT/tmux/scripts/cpu.sh")" \
  'CPU 20%' 'Darwin CPU fixture'
assert_eq "$(PATH="$fixture/bin:/usr/bin:/bin" DOTFILES_TEST_OS=Darwin sh "$ROOT/tmux/scripts/ram.sh")" \
  'RAM 3/8GiB' 'Darwin RAM fixture'

run_clipboard_case() {
  local name=$1
  shift
  rm -f "$fixture/clipboard.log"
  PATH="$fixture/bin:/usr/bin:/bin" DOTFILES_TEST_OS=Linux \
    "$ROOT/tmux/scripts/clipboard.sh" <<<'sample' >/dev/null
  assert_eq "$(cat "$fixture/clipboard.log")" "$name" 'clipboard backend and arguments'
}
for backend in wl-copy xclip xsel; do
  cat >"$fixture/bin/$backend" <<EOF
#!/bin/sh
printf '$backend %s\n' "\$*" > "$fixture/clipboard.log"
cat >/dev/null
EOF
  chmod +x "$fixture/bin/$backend"
done
run_clipboard_case 'wl-copy '
rm "$fixture/bin/wl-copy"
run_clipboard_case 'xclip -selection clipboard'
rm "$fixture/bin/xclip"
run_clipboard_case 'xsel --clipboard --input'
rm "$fixture/bin/xsel"
rm -f "$fixture/clipboard.log"
PATH="$fixture/bin:/usr/bin:/bin" DOTFILES_TEST_OS=Linux \
  "$ROOT/tmux/scripts/clipboard.sh" <<<'sample' >/dev/null
[[ ! -e "$fixture/clipboard.log" ]] || fail 'clipboard no-backend fallback'

zshrc="$ROOT/zsh/.zshrc"
pnpm_home() {
  env HOME="$1" XDG_DATA_HOME="${3:-}" PNPM_HOME="${4:-}" \
    zsh -f -c 'OSTYPE="$2"; source "$1"; print -r -- "$PNPM_HOME"' zsh "$zshrc" "$2"
}
assert_eq "$(pnpm_home "$fixture/home" linux '')" "$fixture/home/.local/share/pnpm" 'Linux PNPM default'
assert_eq "$(pnpm_home "$fixture/home" linux "$fixture/xdg")" "$fixture/xdg/pnpm" 'Linux XDG PNPM override'
assert_eq "$(pnpm_home "$fixture/home" darwin '')" "$fixture/home/Library/pnpm" 'Darwin PNPM default'
assert_eq "$(pnpm_home "$fixture/home" linux '' "$fixture/custom")" "$fixture/custom" 'PNPM custom preservation'

printf 'portability tests passed\n'
