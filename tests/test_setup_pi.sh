#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail() {
 echo "FAIL: $*" >&2
 exit 1
}
newtemp() {
 local d=/private/tmp/pi-setup-test-$$-$RANDOM
 mkdir -p "$d"
 printf '%s\n' "$d"
}
fixture() {
 local h=$1
 mkdir -p "$h/bin" "$h/pnpm/bin"
 cat >"$h/bin/node" <<'EOF'
#!/bin/sh
printf 'v22.19.0\n'
EOF
 cat >"$h/bin/pnpm" <<'EOF'
#!/bin/sh
printf 'pnpm %s\n' "$*" >>"$LOG"
if [ "$1" = config ]; then printf '%s/pnpm/bin\n' "$HOME"; fi
exit 0
EOF
 cat >"$h/bin/npm" <<'EOF'
#!/bin/sh
printf 'npm %s\n' "$*" >>"$LOG"
EOF
 cat >"$h/pnpm/bin/pi" <<'EOF'
#!/bin/sh
if [ "$1" = --version ]; then printf '0.85.1\n'; exit 0; fi
printf 'pi %s\n' "$*" >>"$LOG"
printf '%s\n' "$3" >>"$HOME/packages.log"
EOF
 printf '#!/bin/sh\nexec /usr/bin/python3 "$@"\n' >"$h/bin/python3"
 chmod +x "$h/bin"/* "$h/pnpm/bin/pi"
}
run() {
 local h=$1
 shift
 local os=$1
 shift
 HOME="$h" PATH="$h/bin:/usr/bin:/bin" LOG="$h/log" PI_CODING_AGENT_DIR="$h/agent" DOTFILES_TEST_OS="$os"
 export HOME PATH LOG PI_CODING_AGENT_DIR DOTFILES_TEST_OS
 bash "$ROOT/scripts/setup-pi.sh" "$@"
}
for os in Linux Darwin; do
 h=$(newtemp)
 fixture "$h"
 out=$(run "$h" "$os" --dry-run)
 [[ $out == *'@earendil-works/pi-coding-agent@0.85.1'* ]] || fail plan
 [[ ! -e "$h/agent" && ! -e "$h/log" ]] || fail dry-run mutation
done
h=$(newtemp)
fixture "$h"
mkdir "$h/agent"
if run "$h" Linux --dry-run 2>"$h/error"; then fail fresh accepted; fi
grep -q 'Target exists' "$h/error" || fail wrong fresh error
h=$(newtemp)
fixture "$h"
mkdir -p "$h/agent/themes"
printf '{"sentinel":"settings","packages":["npm:other@1"]}\n' >"$h/agent/settings.json"
printf '{"sentinel":"theme"}\n' >"$h/agent/themes/catppuccin-mocha.json"
printf 'auth\n' >"$h/agent/auth.json"
printf 'mcp\n' >"$h/agent/mcp.json"
printf 'model\n' >"$h/agent/models.json"
run "$h" Linux --merge >/dev/null
/usr/bin/python3 - "$h/agent/settings.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1])); assert x['sentinel']=='settings' and 'npm:other@1' in x['packages'] and len(x['packages'])==8
PY
[[ $(cat "$h/agent/auth.json") == auth && $(cat "$h/agent/mcp.json") == mcp ]] || fail private files changed
[[ $(stat -f %Lp "$h/agent/backups") == 700 ]] || fail backup mode
expected='npm:gentle-pi@2.5.0
npm:pi-intercom@0.13.0
npm:pi-web-access@0.28.0
npm:pi-lens@4.1.5
npm:@juicesharp/rpiv-ask-user-question@2.9.0
npm:pi-mcp-adapter@2.32.1
npm:gentle-engram@0.1.12'
[[ $(cat "$h/packages.log") == "$expected" ]] || fail package order
[[ $(stat -f %Lp "$h/agent/backups"/*/settings.json) == 600 ]] || fail settings backup mode
h=$(newtemp)
fixture "$h"
mkdir -p "$h/agent/themes"
printf '{}' >"$h/agent/settings.json"
cat >"$h/pnpm/bin/pi" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then echo 0.85.1; exit; fi
n=\$(wc -l <"$h/packages.log" 2>/dev/null || echo 0); n=\$((n+1)); printf '%s\\n' "\$3" >>"$h/packages.log"; if [ "\$n" -eq 3 ]; then exit 9; fi; exit 0
EOF
chmod +x "$h/pnpm/bin/pi"
if run "$h" Linux --merge 2>"$h/error"; then fail package failure accepted; fi
[[ $(wc -l <"$h/packages.log") -eq 3 ]] || fail later packages invoked
grep -q 'Package failed' "$h/error" || fail wrong package error
[[ ! -e "$h/agent/themes/catppuccin-mocha.json" ]] || fail theme activated after failure
h=$(newtemp)
fixture "$h"
mkdir -p "$h/agent/themes"
ln -s /tmp "$h/agent/settings.json"
if run "$h" Linux --merge 2>"$h/error"; then fail symlink accepted; fi
grep -q 'symlink' "$h/error" || fail symlink error
for version in 10.85.10 0.85.10 0.85.1-beta garbage; do
 h=$(newtemp)
 fixture "$h"
 mkdir -p "$h/agent/themes"
 cat >"$h/pnpm/bin/pi" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then echo "$version"; fi
EOF
 chmod +x "$h/pnpm/bin/pi"
 if run "$h" Linux --merge 2>"$h/error"; then fail "version accepted: $version"; fi
 grep -q 'version mismatch' "$h/error" || fail "version error: $version"
done
h=$(newtemp)
fixture "$h"
mkdir -p "$h/agent"
ln -s /tmp "$h/agent/themes"
if run "$h" Linux --merge 2>"$h/error"; then fail themes symlink accepted; fi
grep -q symlink "$h/error" || fail themes symlink error
h=$(newtemp)
fixture "$h"
mkdir -p "$h/agent/themes"
ln -s /tmp "$h/agent/settings.json"
if run "$h" Linux --merge 2>"$h/error"; then fail dangling settings accepted; fi
grep -q symlink "$h/error" || fail dangling settings error
h=$(newtemp)
fixture "$h"
mkdir -p "$h/agent/themes"
ln -s /tmp "$h/agent/themes/catppuccin-mocha.json"
if run "$h" Linux --merge 2>"$h/error"; then fail dangling theme accepted; fi
grep -q symlink "$h/error" || fail dangling theme error
h=$(newtemp)
fixture "$h"
mkdir -p "$h/real"
ln -s "$h/real" "$h/link"
PI_CODING_AGENT_DIR="$h/link/agent" HOME="$h" PATH="$h/bin:/usr/bin:/bin" LOG="$h/log" DOTFILES_TEST_OS=Linux
export PI_CODING_AGENT_DIR HOME PATH LOG DOTFILES_TEST_OS
if bash "$ROOT/scripts/setup-pi.sh" --merge 2>"$h/error"; then fail ancestor symlink accepted; fi
grep -q symlink "$h/error" || fail ancestor symlink error
printf 'setup-pi tests passed (9 scenarios, 2 platforms)\n'
