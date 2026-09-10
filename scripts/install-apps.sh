#!/usr/bin/env bash
set -euo pipefail

APP_OS=${DOTFILES_TEST_OS:-$(uname -s)}
APP_DRY_RUN=${DOTFILES_DRY_RUN:-0}
APP_SELECT=${DOTFILES_APP_SELECT:-}
APP_DISTRO_FILE=${DOTFILES_OS_RELEASE:-/etc/os-release}
APP_ARCH=${DOTFILES_ARCH:-$(uname -m)}
APP_YES=0
APP_ALLOW_REMOTE=0
APP_FETCH_ONLY=0
APP_APPROVAL_ONLY=0
TEMP_DIRS=()
cleanup() {
  local d
  for d in "${TEMP_DIRS[@]-}"; do [[ -n "$d" ]] && rm -rf "$d" || true; done
  true
}
trap cleanup EXIT
log_app() { printf '[dotfiles] %s\n' "$1"; }
fail_app() {
  log_app "$1" >&2
  return 1
}
usage() { printf '%s\n' 'Usage: scripts/install-apps.sh --yes [--allow-remote-installers] [--dry-run]'; }
while (($#)); do
  case "$1" in
  --yes) APP_YES=1 ;; --allow-remote-installers) APP_ALLOW_REMOTE=1 ;; --dry-run) APP_DRY_RUN=1 ;; -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    fail_app "Unknown option: $1"
    exit 2
    ;;
  esac
  shift
done
((APP_YES == 1)) || {
  usage >&2
  fail_app 'Application phase requires explicit --yes'
  exit 1
}
linux_id= linux_version=
if [[ "$APP_OS" == Linux ]]; then
  [[ -r "$APP_DISTRO_FILE" ]] || {
    fail_app 'Cannot identify Linux distribution'
    exit 1
  }
  while IFS='=' read -r key value; do
    case "$key" in ID)
      linux_id=${value#\"}
      linux_id=${linux_id%\"}
      ;;
    VERSION_ID)
      linux_version=${value#\"}
      linux_version=${linux_version%\"}
      ;;
    esac
  done <"$APP_DISTRO_FILE"
fi
version_ge() {
  local left=${1//./ } right=${2//./ } lmajor lminor rmajor rminor
  read -r lmajor lminor _ <<<"$left"
  read -r rmajor rminor _ <<<"$right"
  lminor=${lminor:-0}
  rminor=${rminor:-0}
  ((lmajor > rmajor || (lmajor == rmajor && lminor >= rminor)))
}
local_bin="$HOME/.local/bin"
installed_app() {
  case "$1" in
  ghostty) [[ "$APP_OS" == Darwin && -d /Applications/Ghostty.app ]] || command -v ghostty >/dev/null 2>&1 ;;
  aerospace) [[ "$APP_OS" == Darwin && -d /Applications/AeroSpace.app ]] || command -v aerospace >/dev/null 2>&1 ;;
  herdr | starship) [[ -x "$local_bin/$1" ]] || command -v "$1" >/dev/null 2>&1 ;;
  *) command -v "$1" >/dev/null 2>&1 ;;
  esac
}
valid_app() { case "$1" in ghostty | tmux | herdr | starship | zsh | opencode | aerospace) ;; *) fail_app "Unknown application: $1" ;; esac }
remote_needed() { [[ "$APP_OS:$1" == Linux:herdr || "$APP_OS:$1" == Linux:starship ]]; }
validate_local_target() {
  local component path=$HOME
  [[ -d "$HOME" && ! -L "$HOME" ]] || {
    fail_app "Unsafe HOME path: $HOME"
    return 1
  }
  for component in .local bin; do
    path="$path/$component"
    if [[ -L "$path" || (-e "$path" && ! -d "$path") ]]; then
      fail_app "Unsafe target path: $path"
      return 1
    fi
    if [[ -e "$path" && ! -w "$path" ]]; then
      fail_app "Target directory is not writable: $path"
      return 1
    fi
  done
}
preflight_remote() {
  local app=$1
  command -v curl >/dev/null 2>&1 || {
    fail_app "$app requires curl"
    return 1
  }
  command -v tar >/dev/null 2>&1 || {
    fail_app "$app requires tar"
    return 1
  }
  if [[ "$app" == herdr ]]; then
    command -v awk >/dev/null 2>&1 || {
      fail_app 'herdr requires awk'
      return 1
    }
    command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || command -v openssl >/dev/null 2>&1 || {
      fail_app 'herdr requires sha256sum, shasum, or openssl'
      return 1
    }
  fi
  validate_local_target || return 1
}
preflight_app() {
  local app=$1
  valid_app "$app" || return 1
  [[ "$APP_ARCH" == x86_64 || "$APP_ARCH" == arm64 || "$APP_ARCH" == aarch64 ]] || {
    fail_app "Unsupported architecture: $APP_ARCH"
    return 1
  }
  if remote_needed "$app"; then validate_local_target || return 1; fi
  if installed_app "$app"; then
    log_app "$app already installed; skipping"
    return 0
  fi
  case "$APP_OS:$app" in
  Linux:aerospace)
    fail_app 'Aerospace is macOS-only'
    return 1
    ;;
  Linux:ghostty)
    [[ "$linux_id" == ubuntu && -n "$linux_version" ]] && version_ge "$linux_version" 26.04 || {
      fail_app 'Ghostty is manual-only on Debian/older Ubuntu; official apt support requires Ubuntu >= 26.04'
      return 1
    }
    command -v apt-get >/dev/null 2>&1 || {
      fail_app 'Ghostty requires apt-get'
      return 1
    }
    ;;
  Linux:tmux | Linux:zsh) command -v apt-get >/dev/null 2>&1 || {
    fail_app "$app requires apt-get"
    return 1
  } ;; Linux:herdr | Linux:starship) preflight_remote "$app" || return 1 ;; Linux:opencode) command -v pnpm >/dev/null 2>&1 || {
    fail_app 'OpenCode on Linux requires existing pnpm'
    return 1
  } ;; Darwin:*) command -v brew >/dev/null 2>&1 || {
    fail_app "$app requires existing Homebrew"
    return 1
  } ;;
  esac
}
HERDR_SCRIPT= STARSHIP_SCRIPT=
remote_install() {
  local app=$1 url script answer
  url=$([[ "$app" == herdr ]] && printf '%s' 'https://herdr.dev/install.sh' || printf '%s' 'https://starship.rs/install.sh')
  script=$([[ "$app" == herdr ]] && printf '%s' "$HERDR_SCRIPT" || printf '%s' "$STARSHIP_SCRIPT")
  if [[ -z "$script" ]]; then
    local tmp_root=${TMPDIR:-/tmp}
    [[ "$tmp_root" != *' '* ]] || {
      fail_app 'TMPDIR with spaces is unsafe for the official installer'
      return 1
    }
    local private_dir
    private_dir=$(mktemp -d "$tmp_root/dotfiles-installer.XXXXXX") || return 1
    TEMP_DIRS+=("$private_dir")
    script="$private_dir/installer.sh"
    chmod 700 "$private_dir"
    curl --proto '=https' --proto-redir '=https' --fail --location --connect-timeout 5 --max-time 30 "$url" -o "$script" || {
      fail_app "Failed to download $app installer"
      return 1
    }
    [[ "$app" == herdr ]] && HERDR_SCRIPT=$script || STARSHIP_SCRIPT=$script
  fi
  if ((APP_DRY_RUN == 1)); then
    log_app "DRY RUN: would download $url and install $app to $local_bin"
    return 0
  fi
  ((APP_FETCH_ONLY == 1)) && return 0
  if ((APP_APPROVAL_ONLY == 1)); then
    if ((APP_ALLOW_REMOTE == 0)); then
      [[ -t 0 ]] || {
        fail_app 'Remote installers require --allow-remote-installers and --yes in noninteractive mode'
        return 1
      }
      printf 'Review %s from %s at %s. Run it? [y/N] ' "$app" "$url" "$script"
      IFS= read -r answer || answer=
      [[ "$answer" == y || "$answer" == Y ]] || {
        fail_app "$app installer declined"
        return 1
      }
    fi
    return 0
  fi
  if ((APP_ALLOW_REMOTE == 0)); then
    [[ -t 0 ]] || {
      fail_app 'Remote installers require --allow-remote-installers and --yes in noninteractive mode'
      return 1
    }
    printf 'Review %s at %s. Run it? [y/N] ' "$app" "$script"
    IFS= read -r answer || answer=
    [[ "$answer" == y || "$answer" == Y ]] || {
      fail_app "$app installer declined"
      return 1
    }
  fi
  mkdir -p "$local_bin"
  [[ -d "$local_bin" && ! -L "$local_bin" && -w "$local_bin" ]] || {
    fail_app "Unsafe or unwritable target: $local_bin"
    return 1
  }
  if [[ "$app" == herdr ]]; then HERDR_INSTALL_DIR="$local_bin" sh "$script"; else sh "$script" --yes --bin-dir "$local_bin"; fi
  [[ -x "$local_bin/$app" ]] || {
    fail_app "$app installer did not create executable $local_bin/$app"
    return 1
  }
}
run_install() {
  local app=$1
  if ((APP_DRY_RUN == 1)); then
    log_app "DRY RUN: install $app"
    return 0
  fi
  case "$APP_OS:$app" in Darwin:ghostty) brew install --cask ghostty ;; Darwin:herdr) brew install herdr ;; Darwin:opencode) brew install anomalyco/tap/opencode ;; Darwin:starship) brew install starship ;; Darwin:tmux | Darwin:zsh) brew install "$app" ;; Darwin:aerospace) brew install --cask nikitabobko/tap/aerospace ;; Linux:herdr | Linux:starship) remote_install "$app" ;; Linux:ghostty) sudo apt-get install -y ghostty ;; Linux:tmux | Linux:zsh) sudo apt-get install -y "$app" ;; Linux:opencode) pnpm install -g opencode-ai ;; *)
    fail_app "No supported installation method for $app on $APP_OS"
    return 1
    ;;
  esac
}
main() {
  [[ -z "$APP_SELECT" ]] && return 0
  local app
  for app in $APP_SELECT; do preflight_app "$app" || return 1; done
  if ((APP_DRY_RUN == 1)); then
    for app in $APP_SELECT; do installed_app "$app" || run_install "$app" || return 1; done
    return 0
  fi
  if ((APP_ALLOW_REMOTE == 0)) && ! [[ -t 0 ]]; then
    for app in $APP_SELECT; do
      if remote_needed "$app" && ! installed_app "$app"; then
        fail_app 'Remote installers require --allow-remote-installers and --yes in noninteractive mode'
        return 1
      fi
    done
  fi
  APP_FETCH_ONLY=1
  for app in $APP_SELECT; do
    if remote_needed "$app" && ! installed_app "$app"; then run_install "$app" || return 1; fi
    true
  done
  APP_FETCH_ONLY=0
  APP_APPROVAL_ONLY=1
  for app in $APP_SELECT; do
    if remote_needed "$app" && ! installed_app "$app"; then run_install "$app" || return 1; fi
    true
  done
  APP_APPROVAL_ONLY=0
  for app in $APP_SELECT; do installed_app "$app" || { run_install "$app" || {
    fail_app "Failed to install $app; links were not changed"
    return 1
  }; }; done
  true
  return 0
}
main "$@"
