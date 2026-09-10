#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SNAPSHOT="$ROOT/config/pi/settings.json"
THEME="$ROOT/config/pi/themes/catppuccin-mocha.json"
CLI_SPEC='@earendil-works/pi-coding-agent@0.85.1'
OS=${DOTFILES_TEST_OS:-$(uname -s)}
case "$OS" in Darwin | Linux) ;; *)
 echo "Unsupported OS: $OS" >&2
 exit 2
 ;;
esac
mode=fresh
dry=0
usage() {
 cat <<'EOF'
Usage: scripts/setup-pi.sh [--dry-run] [--merge]
Install the pinned Pi CLI and snapshot packages, then optionally merge preferences.
Default mode refuses any existing target state. --merge preserves unrelated settings/packages.
EOF
}
while (($#)); do
 case "$1" in --help | -h)
  usage
  exit 0
  ;;
 --dry-run) dry=1 ;; --merge) mode=merge ;; *)
  echo "Unknown option: $1" >&2
  usage >&2
  exit 2
  ;;
 esac
 shift
done
[[ -f "$SNAPSHOT" && -f "$THEME" ]] || {
 echo 'Invalid Pi snapshot' >&2
 exit 1
}
python3 - "$SNAPSHOT" "$THEME" <<'PY'
import json,sys
with open(sys.argv[1]) as f: x=json.load(f)
if not isinstance(x,dict) or not isinstance(x.get('packages'),list) or len(x['packages'])!=7 or not isinstance(x.get('theme'),str): raise SystemExit('invalid snapshot shape')
with open(sys.argv[2]) as f: theme=json.load(f)
if not isinstance(theme,dict): raise SystemExit('invalid theme snapshot')
PY
TARGET=${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}
case "$TARGET" in /*) ;; *)
 echo 'PI_CODING_AGENT_DIR must be absolute' >&2
 exit 1
 ;;
esac
check_path() {
 local p=$1
 [[ ! -L "$p" ]] || {
  echo "Refusing symlink: $p" >&2
  exit 1
 }
 [[ ! -e "$p" || -d "$p" ]] || {
  echo "Refusing non-directory: $p" >&2
  exit 1
 }
}
check_path "$TARGET"
parent=$(dirname "$TARGET")
while [[ "$parent" != / ]]; do
 check_path "$parent"
 parent=$(dirname "$parent")
done
settings="$TARGET/settings.json"
themes="$TARGET/themes"
[[ ! -L "$settings" ]] || {
 echo "Refusing symlink: $settings" >&2
 exit 1
}
[[ ! -e "$settings" || -f "$settings" ]] || {
 echo 'settings.json is not regular' >&2
 exit 1
}
[[ ! -L "$themes" ]] || {
 echo "Refusing symlink: $themes" >&2
 exit 1
}
[[ ! -e "$themes" || -d "$themes" ]] || {
 echo 'themes is not a directory' >&2
 exit 1
}
theme_target="$themes/catppuccin-mocha.json"
[[ ! -L "$theme_target" ]] || {
 echo "Refusing symlink: $theme_target" >&2
 exit 1
}
[[ ! -e "$theme_target" || -f "$theme_target" ]] || {
 echo "Theme target is not regular: $theme_target" >&2
 exit 1
}
if [[ "$mode" == fresh && (-e "$TARGET" || -e "$settings" || -e "$themes") ]]; then
 echo "Target exists; use --merge explicitly: $TARGET" >&2
 exit 1
fi
nodev=$(node --version 2>/dev/null || true)
[[ "$nodev" =~ ^v([0-9]+)\.([0-9]+)\. ]] && ((BASH_REMATCH[1] > 22 || (BASH_REMATCH[1] == 22 && BASH_REMATCH[2] >= 19))) || {
 echo 'Node >=22.19.0 is required' >&2
 exit 1
}
for cmd in python3; do command -v "$cmd" >/dev/null || {
 echo "Missing prerequisite: $cmd" >&2
 exit 1
}; done
specs=()
while IFS= read -r spec; do specs+=("$spec"); done < <(
 python3 - "$SNAPSHOT" <<'PY'
import json,sys
print('\n'.join(json.load(open(sys.argv[1]))['packages']))
PY
)
printf 'Plan (%s): target=%s\n' "$mode" "$TARGET"
printf '  pnpm add --global --ignore-scripts %s\n' "$CLI_SPEC"
printf '  pi install --no-approve %s\n' "${specs[@]}"
((dry)) && exit 0
bin=$(pnpm config get global-bin-dir 2>/dev/null || true)
[[ -n "$bin" && "$bin" != undefined ]] || {
 echo 'pnpm global-bin-dir is not configured' >&2
 exit 1
}
for cmd in pnpm npm; do command -v "$cmd" >/dev/null || {
 echo "Missing prerequisite: $cmd" >&2
 exit 1
}; done
mkdir -p "$TARGET" "$themes"
chmod 700 "$TARGET" "$themes"
backup="$TARGET/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TARGET/backups" "$backup"
chmod 700 "$TARGET/backups" "$backup"
if [[ -f "$settings" ]]; then
 cp "$settings" "$backup/settings.json"
 chmod 600 "$backup/settings.json"
fi
if [[ -f "$theme_target" ]]; then
 cp "$theme_target" "$backup/catppuccin-mocha.json"
 chmod 600 "$backup/catppuccin-mocha.json"
fi
pnpm add --global --ignore-scripts "$CLI_SPEC"
pi_bin="$bin/pi"
[[ -x "$pi_bin" ]] || {
 echo 'Installed pi executable not found' >&2
 exit 1
}
version=$($pi_bin --version 2>/dev/null || true)
[[ "$version" =~ ^0\.85\.1$ ]] || {
 echo "Installed pi version mismatch: $version" >&2
 exit 1
}
for spec in "${specs[@]}"; do (cd / && "$pi_bin" install --no-approve "$spec") || {
 echo "Package failed; partial installation retained: $spec" >&2
 exit 1
}; done
python3 - "$THEME" "$theme_target" <<'PY'
import json,sys,tempfile,os
with open(sys.argv[1]) as f: data=json.load(f)
fd,tmp=tempfile.mkstemp(dir=os.path.dirname(sys.argv[2])); os.chmod(tmp,0o600)
with os.fdopen(fd,'w') as f: json.dump(data,f,indent=2); f.write('\n')
os.replace(tmp,sys.argv[2])
PY
python3 - "$SNAPSHOT" "$settings" <<'PY'
import json,sys,tempfile,os
snap=json.load(open(sys.argv[1])); dst=sys.argv[2]; cur={}
if os.path.exists(dst): cur=json.load(open(dst))
cur['packages']=snap['packages'] if not isinstance(cur.get('packages'),list) else [p for p in cur['packages'] if p not in snap['packages']]+snap['packages']
cur['theme']=snap['theme']; cur['enableSkillCommands']=snap['enableSkillCommands']
fd,tmp=tempfile.mkstemp(dir=os.path.dirname(dst)); os.chmod(tmp,0o600)
with os.fdopen(fd,'w') as f: json.dump(cur,f,indent=2); f.write('\n')
os.replace(tmp,dst)
PY
echo "Pi setup complete; backup: $backup"
