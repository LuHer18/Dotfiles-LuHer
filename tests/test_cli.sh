#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}
assert_contains() { [[ "$1" == *"$2"* ]] || fail "expected $2"; }
assert_no_files() { [[ -z "$(find "$1" -mindepth 1 -print -quit)" ]] || fail "mutated $1"; }
linux_release=$(mktemp)
printf 'ID=ubuntu\n' >"$linux_release"
home=$(mktemp -d)
out=$(DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux,starship --configs-only --dry-run)
assert_contains "$out" 'tmux'
assert_contains "$out" 'starship'
[[ "$out" != *ghostty* ]] || fail 'unselected ghostty in plan'
assert_no_files "$home"
if DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select aerospace --configs-only --yes >/dev/null 2>&1; then fail 'aerospace accepted on Linux'; fi
if DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux,tmux --dry-run >/dev/null 2>&1; then fail 'duplicate accepted'; fi
if printf '' | DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux --configs-only >/dev/null 2>&1; then fail 'nonTTY accepted'; fi
DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux --configs-only --yes >/dev/null
[[ -L "$home/.tmux.conf" ]] || fail 'tmux not linked'
if DOTFILES_OS=Plan9 HOME="$home" bash "$ROOT/dotfiles" setup --select tmux --dry-run >/dev/null 2>&1; then fail 'unknown OS accepted'; fi
pty_output=$(mktemp)
ROOT="$ROOT" HOME="$home" python3 - "$pty_output" <<'PY'
import os, pty, subprocess, sys, time
output_path = sys.argv[1]
env = os.environ.copy()
env.update(DOTFILES_OS='Darwin')
master, slave = pty.openpty()
process = subprocess.Popen(['bash', os.path.join(env['ROOT'], 'dotfiles'), 'setup', '--dry-run'], stdin=slave, stdout=slave, stderr=slave, env=env)
os.close(slave)
os.write(master, b'tmux\n')
chunks = []
deadline = time.time() + 5
while time.time() < deadline:
    try:
        chunks.append(os.read(master, 4096))
        if b'Done' in chunks[-1] or b'Cancelled' in chunks[-1]:
            break
    except OSError:
        break
process.wait(timeout=5)
os.close(master)
with open(output_path, 'wb') as stream:
    stream.write(b''.join(chunks))
PY
mac_out=$(<"$pty_output")
assert_contains "$mac_out" 'aerospace'
linux_menu_output=$(mktemp)
cancel_home=$(mktemp -d)
ROOT="$ROOT" HOME="$cancel_home" DOTFILES_OS_RELEASE="$linux_release" python3 - "$linux_menu_output" <<'PY'
import os, pty, subprocess, sys
path = sys.argv[1]
env = os.environ.copy()
env.update(DOTFILES_OS='Linux', DOTFILES_OS_RELEASE=os.environ['DOTFILES_OS_RELEASE'])
master, slave = pty.openpty()
process = subprocess.Popen(['bash', os.path.join(env['ROOT'], 'dotfiles'), 'setup'], stdin=slave, stdout=slave, stderr=slave, env=env)
os.close(slave)
os.write(master, b'\n')
process.wait(timeout=5)
with open(path, 'wb') as stream:
    stream.write(os.read(master, 4096))
os.close(master)
PY
linux_menu_out=$(<"$linux_menu_output")
[[ "$linux_menu_out" != *aerospace* ]] || fail 'Linux menu offered Aerospace'
[[ ! -e "$cancel_home/.config" && ! -e "$cancel_home/.tmux.conf" && ! -e "$cancel_home/.dotfiles-backups" ]] || fail 'cancelled menu created dotfile state'
# Pi integration regression: fake every manager and run fresh plus explicit merge in temp homes.
run_pi_case() {
  local mode=$1 pi_home=$2 fake_bin=$3 bin_dir=$4 log=$5
  mkdir -p "$fake_bin" "$bin_dir"
  cat >"$fake_bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'node %s\n' "$*" >>"$PI_LOG"
printf 'v22.19.0\n'
EOF
  cat >"$fake_bin/pnpm" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == config && "$2" == get ]]; then printf '%s\n' "$PI_BIN_DIR"; fi
if [[ "$1" == add ]]; then
  mkdir -p "$PI_BIN_DIR"
  cat >"$PI_BIN_DIR/pi" <<'PIEOF'
#!/usr/bin/env bash
if [[ "$1" == --version ]]; then echo 0.85.1; else printf 'pi %s\n' "$*" >>"$PI_LOG"; fi
PIEOF
  chmod +x "$PI_BIN_DIR/pi"
fi
EOF
  cat >"$fake_bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$fake_bin/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >>"$PI_LOG"
exit 0
EOF
  chmod +x "$fake_bin/node" "$fake_bin/pnpm" "$fake_bin/npm" "$fake_bin/brew"
  if [[ "$mode" == merge ]]; then
    mkdir -p "$pi_home/.pi/agent"
    printf '{}\n' >"$pi_home/.pi/agent/settings.json"
  fi
  PI_LOG="$log" PI_BIN_DIR="$bin_dir" PI_CODING_AGENT_DIR="$pi_home/pi-agent" DOTFILES_OS=Darwin HOME="$pi_home" PATH="$fake_bin:/usr/bin:/bin" bash "$ROOT/dotfiles" setup --select tmux,pi --yes $([[ "$mode" == merge ]] && printf -- '--pi-merge') >/dev/null
  [[ -f "$log" ]] || fail "missing fake manager log ($mode)"
  if [[ "$mode" == merge ]]; then assert_contains "$(cat "$log")" 'pi install'; fi
  [[ -z "$(find "$pi_home" -type f -name '*.pyc' -print -quit)" ]] || fail "Pi created Python bytecode ($mode)"
}
missing_pi_home=$(mktemp -d /private/tmp/dotfiles-pi.XXXXXX)
missing_pi_bin=$(mktemp -d)
missing_pi_log=$(mktemp)
cat >"$missing_pi_bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'v22.19.0\n'
EOF
cat >"$missing_pi_bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$missing_pi_bin/brew" <<'EOF'
#!/usr/bin/env bash
printf 'MUTATION\n' >>"$MISSING_PI_LOG"
EOF
chmod +x "$missing_pi_bin/node" "$missing_pi_bin/npm" "$missing_pi_bin/brew"
if MISSING_PI_LOG="$missing_pi_log" PI_CODING_AGENT_DIR="$missing_pi_home/pi-agent" DOTFILES_OS=Darwin HOME="$missing_pi_home" PATH="$missing_pi_bin:/usr/bin:/bin" bash "$ROOT/dotfiles" setup --select tmux,pi --yes >/dev/null 2>&1; then fail 'missing pnpm accepted'; fi
[[ ! -s "$missing_pi_log" ]] || fail 'app manager ran before missing Pi dependency was reported'
pi_fresh_home=$(mktemp -d /private/tmp/dotfiles-pi.XXXXXX)
pi_fresh_bin=$(mktemp -d)
pi_fresh_global=$(mktemp -d)
pi_fresh_log=$(mktemp)
run_pi_case fresh "$pi_fresh_home" "$pi_fresh_bin" "$pi_fresh_global" "$pi_fresh_log"
pi_merge_home=$(mktemp -d /private/tmp/dotfiles-pi.XXXXXX)
pi_merge_bin=$(mktemp -d)
pi_merge_global=$(mktemp -d)
pi_merge_log=$(mktemp)
run_pi_case merge "$pi_merge_home" "$pi_merge_bin" "$pi_merge_global" "$pi_merge_log"
printf 'cli tests passed\n'
