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
out=$(DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux,starship --dry-run)
assert_contains "$out" 'tmux'
assert_contains "$out" 'starship'
[[ "$out" != *ghostty* ]] || fail 'unselected ghostty in plan'
assert_no_files "$home"
if DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select aerospace --yes >/dev/null 2>&1; then fail 'aerospace accepted on Linux'; fi
if DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux,tmux --dry-run >/dev/null 2>&1; then fail 'duplicate accepted'; fi
if printf '' | DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux >/dev/null 2>&1; then fail 'nonTTY accepted'; fi
DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$linux_release" HOME="$home" bash "$ROOT/dotfiles" setup --select tmux --yes >/dev/null
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
printf 'cli tests passed\n'
