#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${HOME}/.dotfiles-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
CREATED_BACKUP_DIR=0
DRY_RUN=0
MULTIPLEXER=both
SELECT=""
OS="${DOTFILES_TEST_OS:-$(uname -s)}"
case "$OS" in Darwin | Linux) ;; *)
 printf '[dotfiles] Unsupported OS: %s\n' "$OS" >&2
 exit 1
 ;;
esac
[[ "$OS" == Linux ]] && printf '[dotfiles] Linux detected; skipping Aerospace\n'
usage() {
 cat <<'EOF'
Usage: ./install.sh [--dry-run] [--multiplexer tmux|herdr|both] [--select LIST]
  -n, --dry-run                 Preview without changing files
  --multiplexer VALUE           Link tmux, Herdr, or both (default: both)
  --select LIST                 Comma-separated config IDs (ghostty,tmux,herdr,starship,zsh,opencode,aerospace)
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
 [[ -e "$target" && ! -L "$target" || -L "$target" ]] || return 0
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
has_selection() {
 case ",$1," in
 *",$2,"*) return 0 ;;
 *) return 1 ;;
 esac
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
  --select)
   [[ $# -gt 1 && -n "$2" ]] || {
    log 'Missing selection'
    exit 1
   }
   SELECT=$2
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
 if [[ -n "$SELECT" ]]; then
  local id
  [[ "$SELECT" != ,* && "$SELECT" != *, && "$SELECT" != *,,* ]] || {
   log 'Invalid empty selection'
   exit 1
  }
  for id in ${SELECT//,/ }; do case $id in ghostty | tmux | herdr | starship | zsh | opencode | aerospace) ;; *)
   log "Unknown config: $id"
   exit 1
   ;;
  esac done
  [[ $(printf '%s\n' "$SELECT" | tr ',' '\n' | sort -u | wc -l | tr -d ' ') == $(printf '%s\n' "$SELECT" | tr ',' '\n' | wc -l | tr -d ' ') ]] || {
   log 'Duplicate selection'
   exit 1
  }
  if [[ "$OS" != Darwin ]] && has_selection "$SELECT" aerospace; then
   log 'Aerospace is macOS-only'
   exit 1
  fi
 fi
}
main() {
 parse_args "$@"
 local -a sources=() targets=()
 add_link() {
  sources+=("$1")
  targets+=("$2")
 }
 if [[ -z $SELECT ]]; then
  SELECT=ghostty,opencode,starship,zsh
  [[ $OS == Darwin ]] && SELECT+=,aerospace
  [[ $MULTIPLEXER == tmux || $MULTIPLEXER == both ]] && SELECT+=,tmux
  [[ $MULTIPLEXER == herdr || $MULTIPLEXER == both ]] && SELECT+=,herdr
 fi
 if has_selection "$SELECT" ghostty; then
  add_link "$REPO_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
 fi
 if has_selection "$SELECT" opencode; then
  add_link "$REPO_DIR/config/opencode/tui.json" "$HOME/.config/opencode/tui.json"
 fi
 if has_selection "$SELECT" starship; then
  add_link "$REPO_DIR/config/starship.toml" "$HOME/.config/starship.toml"
 fi
 if has_selection "$SELECT" zsh; then
  add_link "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
 fi
 if has_selection "$SELECT" aerospace; then
  add_link "$REPO_DIR/config/aerospace/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
 fi
 if has_selection "$SELECT" tmux; then
  add_link "$REPO_DIR/tmux/scripts" "$HOME/.config/tmux/scripts"
  add_link "$REPO_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
 fi
 if has_selection "$SELECT" herdr; then
  add_link "$REPO_DIR/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
 fi
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
