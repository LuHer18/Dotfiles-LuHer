#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${HOME}/.dotfiles-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
CREATED_BACKUP_DIR=0
DRY_RUN=0
MULTIPLEXER=both
OS="${DOTFILES_TEST_OS:-$(uname -s)}"
case "$OS" in Darwin | Linux) ;; *)
  printf '[dotfiles] Unsupported OS: %s\n' "$OS" >&2
  exit 1
  ;;
esac
[[ "$OS" == Linux ]] && printf '[dotfiles] Linux detected; skipping Aerospace\n'

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run] [--multiplexer tmux|herdr|both]
  -n, --dry-run                 Preview without changing files
  --multiplexer VALUE           Link tmux, Herdr, or both (default: both)
  -h, --help                    Show this help
EOF
}
log() { printf '[dotfiles] %s\n' "$1"; }
run_cmd() {
  [[ $DRY_RUN -eq 1 ]] && {
    log "DRY RUN: $*"
    return
  }
  "$@"
}
did_or_would() { [[ $DRY_RUN -eq 1 ]] && printf 'Would %s' "$1" || printf '%s' "$1"; }
ensure_backup_dir() { [[ $CREATED_BACKUP_DIR -eq 1 ]] || {
  run_cmd mkdir -p "$BACKUP_DIR"
  CREATED_BACKUP_DIR=1
}; }
backup_target() {
  local target=$1 relative backup
  if [[ ! -e "$target" && ! -L "$target" ]]; then return 0; fi
  ensure_backup_dir
  relative=${target#"$HOME/"}
  backup="$BACKUP_DIR/$relative"
  run_cmd mkdir -p "$(dirname "$backup")"
  run_cmd mv "$target" "$backup"
  log "$(did_or_would 'Back up') $target -> $backup"
}
create_link() {
  local source=$1 target=$2
  [[ -L "$target" && $(readlink "$target") == "$source" ]] && {
    log "Already linked $target -> $source"
    return
  }
  run_cmd mkdir -p "$(dirname "$target")"
  backup_target "$target"
  run_cmd ln -sfn "$source" "$target"
  log "$(did_or_would 'Link') $target -> $source"
}
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in -n | --dry-run) DRY_RUN=1 ;; --multiplexer)
      [[ $# -gt 1 ]] || {
        log 'Missing multiplexer value'
        exit 1
      }
      MULTIPLEXER=$2
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      log "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done
  case $MULTIPLEXER in tmux | herdr | both) ;; *)
    log "Invalid multiplexer: $MULTIPLEXER"
    exit 1
    ;;
  esac
}
main() {
  parse_args "$@"
  local -a sources=("$REPO_DIR/config/ghostty/config" "$REPO_DIR/config/opencode/tui.json" "$REPO_DIR/config/starship.toml" "$REPO_DIR/zsh/.zshrc") targets=("$HOME/.config/ghostty/config" "$HOME/.config/opencode/tui.json" "$HOME/.config/starship.toml" "$HOME/.zshrc")
  [[ $OS == Darwin ]] && {
    sources+=("$REPO_DIR/config/aerospace/aerospace.toml")
    targets+=("$HOME/.config/aerospace/aerospace.toml")
  }
  [[ $MULTIPLEXER == tmux || $MULTIPLEXER == both ]] && {
    sources+=("$REPO_DIR/tmux/scripts" "$REPO_DIR/tmux/.tmux.conf")
    targets+=("$HOME/.config/tmux/scripts" "$HOME/.tmux.conf")
  }
  [[ $MULTIPLEXER == herdr || $MULTIPLEXER == both ]] && {
    sources+=("$REPO_DIR/config/herdr/config.toml")
    targets+=("$HOME/.config/herdr/config.toml")
  }
  local i
  for i in "${!sources[@]}"; do
    [[ -e ${sources[i]} ]] || {
      log "Missing source: ${sources[i]}"
      exit 1
    }
    create_link "${sources[i]}" "${targets[i]}"
  done
  [[ $CREATED_BACKUP_DIR -eq 1 ]] && log "Backups stored in $BACKUP_DIR" || log 'No existing files required backup'
  log Done
}
main "$@"
