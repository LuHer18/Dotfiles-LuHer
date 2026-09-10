#!/usr/bin/env bash
set -euo pipefail

APP_OS=${DOTFILES_TEST_OS:-$(uname -s)}
APP_DRY_RUN=${DOTFILES_DRY_RUN:-0}
APP_SELECT=${DOTFILES_APP_SELECT:-}
APP_DISTRO_FILE=${DOTFILES_OS_RELEASE:-/etc/os-release}
APP_ARCH=${DOTFILES_ARCH:-$(uname -m)}
APP_YES=0
log_app() { printf '[dotfiles] %s\n' "$1"; }
fail_app() {
  log_app "$1" >&2
  return 1
}
usage() { printf '%s\n' 'Usage: scripts/install-apps.sh --yes [--dry-run]'; }
while (($#)); do
  case "$1" in --yes) APP_YES=1 ;; --dry-run) APP_DRY_RUN=1 ;; -h | --help)
    usage
    exit 0
    ;;
  *)
    usage >&2
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
    case "$key" in
    ID)
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
installed_app() {
  case "$1" in
  ghostty) [[ "$APP_OS" == Darwin && -d /Applications/Ghostty.app ]] || command -v ghostty >/dev/null 2>&1 ;;
  aerospace) [[ "$APP_OS" == Darwin && -d /Applications/AeroSpace.app ]] || command -v aerospace >/dev/null 2>&1 ;;
  *) command -v "$1" >/dev/null 2>&1 ;;
  esac
}
valid_app() { case "$1" in ghostty | tmux | herdr | starship | zsh | opencode | aerospace) ;; *) fail_app "Unknown application: $1" ;; esac }
preflight_app() {
  local app=$1
  valid_app "$app" || return 1
  [[ "$APP_ARCH" == x86_64 || "$APP_ARCH" == arm64 || "$APP_ARCH" == aarch64 ]] || fail_app "Unsupported architecture: $APP_ARCH" || return 1
  if installed_app "$app"; then
    log_app "$app already installed; skipping"
    return 0
  fi
  case "$APP_OS:$app" in
  Linux:aerospace) fail_app 'Aerospace is macOS-only' || return 1 ;;
  Linux:ghostty)
    [[ "$linux_id" == ubuntu && -n "$linux_version" ]] && version_ge "$linux_version" 26.04 || { fail_app 'Ghostty is manual-only on Debian/older Ubuntu; official apt support requires Ubuntu >= 26.04' || return 1; }
    command -v apt-get >/dev/null 2>&1 || {
      fail_app 'Ghostty requires apt-get'
      return 1
    }
    ;;
  Linux:tmux | Linux:zsh) command -v apt-get >/dev/null 2>&1 || {
    fail_app "$app requires apt-get"
    return 1
  } ;;
  Linux:herdr | Linux:starship) command -v brew >/dev/null 2>&1 || {
    fail_app "$app on Linux requires existing Linuxbrew (see official documentation)"
    return 1
  } ;;
  Linux:opencode) command -v pnpm >/dev/null 2>&1 || {
    fail_app 'OpenCode on Linux requires existing pnpm'
    return 1
  } ;;
  Darwin:*) command -v brew >/dev/null 2>&1 || {
    fail_app "$app requires existing Homebrew"
    return 1
  } ;;
  esac
}
run_install() {
  local app=$1
  ((APP_DRY_RUN == 1)) && {
    log_app "DRY RUN: install $app"
    return 0
  }
  case "$APP_OS:$app" in
  Darwin:ghostty) brew install --cask ghostty ;; Darwin:herdr) brew install herdr ;; Darwin:opencode) brew install anomalyco/tap/opencode ;; Darwin:starship) brew install starship ;; Darwin:tmux | Darwin:zsh) brew install "$app" ;; Darwin:aerospace) brew install --cask nikitabobko/tap/aerospace ;;
  Linux:ghostty) sudo apt-get install -y ghostty ;; Linux:tmux | Linux:zsh) sudo apt-get install -y "$app" ;; Linux:herdr | Linux:starship) brew install "$app" ;; Linux:opencode) pnpm install -g opencode-ai ;;
  *)
    fail_app "No supported installation method for $app on $APP_OS"
    return 1
    ;;
  esac
}
main() {
  [[ -z "$APP_SELECT" ]] && return 0
  local app
  for app in $APP_SELECT; do preflight_app "$app" || return 1; done
  for app in $APP_SELECT; do installed_app "$app" || { run_install "$app" || {
    fail_app "Failed to install $app; links were not changed"
    return 1
  }; }; done
}
main "$@"
