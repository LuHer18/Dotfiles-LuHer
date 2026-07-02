#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${HOME}/.dotfiles-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
CREATED_BACKUP_DIR=0
DRY_RUN=0

LINK_SOURCES=(
  "${REPO_DIR}/config/ghostty/config"
  "${REPO_DIR}/config/aerospace/aerospace.toml"
  "${REPO_DIR}/config/starship.toml"
  "${REPO_DIR}/tmux/scripts"
  "${REPO_DIR}/tmux/.tmux.conf"
  "${REPO_DIR}/zsh/.zshrc"
)

LINK_TARGETS=(
  "${HOME}/.config/ghostty/config"
  "${HOME}/.config/aerospace/aerospace.toml"
  "${HOME}/.config/starship.toml"
  "${HOME}/.config/tmux/scripts"
  "${HOME}/.tmux.conf"
  "${HOME}/.zshrc"
)

log() {
  printf '[dotfiles] %s\n' "$1"
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [--dry-run]

Options:
  -n, --dry-run  Print the actions without changing files
  -h, --help     Show this help text

Restore backups manually from ~/.dotfiles-backups/<timestamp>/ if needed.
EOF
}

run_cmd() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log "DRY RUN: $*"
    return 0
  fi

  "$@"
}

did_or_would() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    printf 'Would %s' "$1"
  else
    printf '%s' "$1"
  fi
}

ensure_backup_dir() {
  if [[ ${CREATED_BACKUP_DIR} -eq 0 ]]; then
    run_cmd mkdir -p "${BACKUP_DIR}"
    CREATED_BACKUP_DIR=1
  fi
}

backup_target() {
  local target="$1"

  if [[ ! -e "${target}" && ! -L "${target}" ]]; then
    return 0
  fi

  ensure_backup_dir

  local relative_target
  relative_target="${target#${HOME}/}"
  local backup_path="${BACKUP_DIR}/${relative_target}"

  run_cmd mkdir -p "$(dirname "${backup_path}")"
  run_cmd mv "${target}" "${backup_path}"
  log "$(did_or_would "Back up") ${target} -> ${backup_path}"
}

create_link() {
  local source="$1"
  local target="$2"

  if [[ -L "${target}" ]] && [[ "$(readlink "${target}")" == "${source}" ]]; then
    log "Already linked ${target} -> ${source}"
    return 0
  fi

  run_cmd mkdir -p "$(dirname "${target}")"
  backup_target "${target}"
  run_cmd ln -sfn "${source}" "${target}"
  log "$(did_or_would "Link") ${target} -> ${source}"
}

print_restore_hint() {
  if [[ ${CREATED_BACKUP_DIR} -eq 1 ]]; then
    log "To restore a backup, remove the managed symlink first, then move the saved file from ${BACKUP_DIR}"
    log "Example: rm ${HOME}/.zshrc && mv ${BACKUP_DIR}/.zshrc ${HOME}/.zshrc"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        DRY_RUN=1
        ;;
      -h|--help)
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
}

main() {
  parse_args "$@"

  local index
  local source
  local target

  if [[ ${#LINK_SOURCES[@]} -ne ${#LINK_TARGETS[@]} ]]; then
    log "Internal error: link sources and targets are out of sync"
    exit 1
  fi

  for index in "${!LINK_SOURCES[@]}"; do
    source="${LINK_SOURCES[${index}]}"
    target="${LINK_TARGETS[${index}]}"

    if [[ ! -e "${source}" ]]; then
      log "Missing source file: ${source}"
      exit 1
    fi

    create_link "${source}" "${target}"
  done

  if [[ ${CREATED_BACKUP_DIR} -eq 1 ]]; then
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log "Dry run only: backups would be stored in ${BACKUP_DIR}"
    else
      log "Backups stored in ${BACKUP_DIR}"
    fi
  else
    log "No existing files required backup"
  fi

  print_restore_hint

  log "Done"
}

main "$@"
