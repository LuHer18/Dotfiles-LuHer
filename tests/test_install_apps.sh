#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}
release=$(mktemp)
printf 'ID=ubuntu\nVERSION_ID=26.04\n' >"$release"
base_home=$(mktemp -d)
old_release=$(mktemp)
printf 'ID=ubuntu\nVERSION_ID=24.04\n' >"$old_release"
# Existing platform and macOS dry-run coverage.
out=$(HOME="$base_home" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$old_release" DOTFILES_APP_SELECT='ghostty tmux' DOTFILES_DRY_RUN=1 PATH="/usr/bin:/bin" bash "$ROOT/scripts/install-apps.sh" --yes 2>&1) && fail 'unsupported Ghostty accepted' || :
[[ "$out" == *manual-only* ]] || fail 'missing Ghostty guide'
mac_bin=$(mktemp -d)
mac_log=$(mktemp)
printf '#!/usr/bin/env bash\nprintf brew >>"$MAC_LOG"\n' >"$mac_bin/brew"
chmod +x "$mac_bin/brew"
out=$(HOME="$base_home" MAC_LOG="$mac_log" DOTFILES_TEST_OS=Darwin DOTFILES_APP_SELECT=herdr DOTFILES_DRY_RUN=1 PATH="$mac_bin:/usr/bin:/bin" bash "$ROOT/scripts/install-apps.sh" --yes) || fail 'macOS dry run failed'
[[ "$out" == *'DRY RUN: install herdr'* && ! -s "$mac_log" ]] || fail 'macOS brew dry-run regression'

# Fake tools only write test fixtures; no downloaded or real installer is executed.
make_tools() {
  tools=$1 log=$2
  mkdir -p "$tools"
  cat >"$tools/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl:%s\n' "$*" >>"$REMOTE_LOG"
for ((i=1; i <= $#; i++)); do [[ "${!i}" == -o ]] && { j=$((i + 1)); out=${!j}; }; done
[[ "${CURL_MODE:-success}" == fail ]] && exit 22
cat >"$out" <<'SH'
#!/usr/bin/env bash
if [[ "${INSTALL_MODE:-success}" == no-artifact ]]; then exit 0; fi
if [[ -n "${HERDR_INSTALL_DIR:-}" ]]; then
  printf 'installer:herdr:%s:%s\n' "$HERDR_INSTALL_DIR" "$*" >>"$REMOTE_LOG"
  target="$HERDR_INSTALL_DIR/herdr"
else
  printf 'installer:starship::%s\n' "$*" >>"$REMOTE_LOG"
  target="$3/starship"
fi
mkdir -p "$(dirname "$target")"
printf '#!/bin/sh\n' >"$target"; chmod +x "$target"
SH
chmod +x "$out"
EOF
  cat >"$tools/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt:%s\n' "$*" >>"$REMOTE_LOG"
EOF
  chmod +x "$tools/curl" "$tools/apt-get"
}

# RED regression: a .local symlink formerly let the fixture write into its victim.
symlink_home=$(mktemp -d)
victim=$(mktemp -d)
symlink_tools=$(mktemp -d)
symlink_log=$(mktemp)
make_tools "$symlink_tools" "$symlink_log" success
ln -s "$victim" "$symlink_home/.local"
if REMOTE_LOG="$symlink_log" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$symlink_home" PATH="$symlink_tools:/usr/bin:/bin" DOTFILES_APP_SELECT='tmux herdr' bash "$ROOT/scripts/install-apps.sh" --yes --allow-remote-installers >/dev/null 2>&1; then fail '.local symlink accepted'; fi
[[ ! -s "$symlink_log" && ! -e "$victim/bin/herdr" ]] || fail '.local symlink caused mutation'
# Direct bin symlink and symlinked HOME use the same pre-download policy.
for kind in bin home; do
  h=$(mktemp -d)
  v=$(mktemp -d)
  link_home=$h
  if [[ "$kind" == bin ]]; then
    mkdir -p "$h/.local"
    ln -s "$v" "$h/.local/bin"
  else
    link_home=$(mktemp -d)/home
    ln -s "$h" "$link_home"
  fi
  : >"$symlink_log"
  if REMOTE_LOG="$symlink_log" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$link_home" PATH="$symlink_tools:/usr/bin:/bin" DOTFILES_APP_SELECT=herdr bash "$ROOT/scripts/install-apps.sh" --yes --allow-remote-installers >/dev/null 2>&1; then fail "$kind symlink accepted"; fi
  [[ ! -s "$symlink_log" ]] || fail "$kind symlink downloaded before rejection"
done

# Dry-run must not create temporary files or invoke curl/managers.
dry_home=$(mktemp -d)
dry_tmp=$(mktemp -d)
dry_tools=$(mktemp -d)
dry_log=$(mktemp)
make_tools "$dry_tools" "$dry_log" success
REMOTE_LOG="$dry_log" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$dry_home" TMPDIR="$dry_tmp" PATH="$dry_tools:/usr/bin:/bin" DOTFILES_APP_SELECT='herdr starship' DOTFILES_DRY_RUN=1 bash "$ROOT/scripts/install-apps.sh" --yes >/dev/null
[[ ! -s "$dry_log" && -z "$(find "$dry_home" "$dry_tmp" -mindepth 1 -print -quit)" ]] || fail 'dry run wrote HOME/temp or invoked a tool'

# Failed curl owns and removes its private directory immediately.
fail_home=$(mktemp -d)
fail_tmp=$(mktemp -d)
fail_tools=$(mktemp -d)
fail_log=$(mktemp)
make_tools "$fail_tools" "$fail_log" fail
if REMOTE_LOG="$fail_log" CURL_MODE=fail DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$fail_home" TMPDIR="$fail_tmp" PATH="$fail_tools:/usr/bin:/bin" DOTFILES_APP_SELECT=herdr bash "$ROOT/scripts/install-apps.sh" --yes --allow-remote-installers >/dev/null 2>&1; then fail 'failed curl accepted'; fi
[[ -z "$(find "$fail_tmp" -mindepth 1 -print -quit)" ]] || fail 'failed curl leaked private temp directory'

# Both official scripts receive exact supported invocation contracts and make artifacts.
success_home=$(mktemp -d)
success_tools=$(mktemp -d)
success_log=$(mktemp)
make_tools "$success_tools" "$success_log" success
REMOTE_LOG="$success_log" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$success_home" PATH="$success_tools:/usr/bin:/bin" DOTFILES_APP_SELECT='herdr starship' bash "$ROOT/scripts/install-apps.sh" --yes --allow-remote-installers >/dev/null
[[ -x "$success_home/.local/bin/herdr" && -x "$success_home/.local/bin/starship" ]] || fail 'successful fake installers did not create artifacts'
log=$(<"$success_log")
[[ "$log" == *'--proto =https --proto-redir =https --fail --location --connect-timeout 5 --max-time 30 https://herdr.dev/install.sh'* ]] || fail 'Herdr curl HTTPS flags missing'
[[ "$log" == *'https://starship.rs/install.sh'* && "$log" == *"installer:herdr:$success_home/.local/bin:"* && "$log" == *"installer:starship::--yes --bin-dir $success_home/.local/bin"* ]] || fail 'official script arguments incorrect'

# Installer success without the expected executable must fail before links can be applied.
no_artifact_home=$(mktemp -d)
no_artifact_tools=$(mktemp -d)
no_artifact_log=$(mktemp)
make_tools "$no_artifact_tools" "$no_artifact_log" success
if REMOTE_LOG="$no_artifact_log" INSTALL_MODE=no-artifact DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$no_artifact_home" PATH="$no_artifact_tools:/usr/bin:/bin" DOTFILES_APP_SELECT=herdr bash "$ROOT/scripts/install-apps.sh" --yes --allow-remote-installers >/dev/null 2>&1; then fail 'missing executable accepted'; fi
[[ ! -e "$no_artifact_home/.local/bin/herdr" ]] || fail 'missing-artifact installer created binary'

# --yes alone rejects before downloading; existing ~/.local binary skips even when absent from PATH.
opt_home=$(mktemp -d)
opt_tools=$(mktemp -d)
opt_log=$(mktemp)
make_tools "$opt_tools" "$opt_log" success
if REMOTE_LOG="$opt_log" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$opt_home" PATH="$opt_tools:/usr/bin:/bin" DOTFILES_APP_SELECT=herdr bash "$ROOT/scripts/install-apps.sh" --yes </dev/null >/dev/null 2>&1; then fail '--yes alone allowed remote install'; fi
[[ ! -s "$opt_log" ]] || fail '--yes alone downloaded script'
mkdir -p "$opt_home/.local/bin"
printf '#!/bin/sh\n' >"$opt_home/.local/bin/herdr"
chmod +x "$opt_home/.local/bin/herdr"
: >"$opt_log"
REMOTE_LOG="$opt_log" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$opt_home" PATH="$opt_tools:/usr/bin:/bin" DOTFILES_APP_SELECT=herdr bash "$ROOT/scripts/install-apps.sh" --yes --allow-remote-installers >/dev/null
[[ ! -s "$opt_log" ]] || fail 'existing local binary was overwritten'

# Both approval prompts precede managers/installers: decline Starship after accepting Herdr.
pty_home=$(mktemp -d)
pty_tools=$(mktemp -d)
pty_log=$(mktemp)
make_tools "$pty_tools" "$pty_log" success
ROOT="$ROOT" RELEASE="$release" HOME="$pty_home" REMOTE_LOG="$pty_log" PATH="$pty_tools:/usr/bin:/bin" python3 - <<'PY'
import os, pty, subprocess, time
master, slave = pty.openpty()
env = os.environ.copy(); env.update(DOTFILES_TEST_OS='Linux', DOTFILES_OS_RELEASE=env['RELEASE'], DOTFILES_APP_SELECT='tmux herdr starship')
p = subprocess.Popen(['bash', os.path.join(env['ROOT'], 'scripts/install-apps.sh'), '--yes'], stdin=slave, stdout=slave, stderr=slave, env=env)
os.close(slave); data = b''; sent = 0; deadline = time.time() + 5
while time.time() < deadline and p.poll() is None:
    try: chunk = os.read(master, 4096)
    except OSError: break
    data += chunk
    while data.count(b'Run it?') > sent:
        os.write(master, b'y\n' if sent == 0 else b'n\n'); sent += 1
p.wait(timeout=5); os.close(master)
if sent != 2 or p.returncode == 0: raise SystemExit('expected two prompts and decline failure: ' + repr(data))
PY
pty_result=$(<"$pty_log")
[[ "$pty_result" == *'https://herdr.dev/install.sh'* && "$pty_result" == *'https://starship.rs/install.sh'* ]] || fail 'both scripts were not downloaded before approval'
[[ "$pty_result" != *apt:* && "$pty_result" != *installer:* ]] || fail 'manager or installer ran before all approvals'

# Missing remote prerequisites fail before downloads.
missing_home=$(mktemp -d)
missing_log=$(mktemp)
if REMOTE_LOG="$missing_log" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE="$release" HOME="$missing_home" PATH="/bin" DOTFILES_APP_SELECT=herdr bash "$ROOT/scripts/install-apps.sh" --yes --allow-remote-installers >/dev/null 2>&1; then fail 'missing curl accepted'; fi
printf 'install-apps tests passed (remote assertions: 17)\n'
