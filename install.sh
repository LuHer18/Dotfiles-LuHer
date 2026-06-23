#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${HOME}/.dotfiles-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
CREATED_BACKUP_DIR=0

LINKS=(
  "${REPO_DIR}/config/ghostty/config:${HOME}/.config/ghostty/config"
  "${REPO_DIR}/config/starship.toml:${HOME}/.config/starship.toml"
  "${REPO_DIR}/tmux/.tmux.conf:${HOME}/.tmux.conf"
  "${REPO_DIR}/zsh/.zshrc:${HOME}/.zshrc"
)

log() {
  printf '[dotfiles] %s\n' "$1"
}

ensure_backup_dir() {
  if [[ ${CREATED_BACKUP_DIR} -eq 0 ]]; then
    mkdir -p "${BACKUP_DIR}"
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

  mkdir -p "$(dirname "${backup_path}")"
  mv "${target}" "${backup_path}"
  log "Backed up ${target} -> ${backup_path}"
}

create_link() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "${target}")"
  backup_target "${target}"
  ln -sfn "${source}" "${target}"
  log "Linked ${target} -> ${source}"
}

main() {
  for mapping in "${LINKS[@]}"; do
    IFS=':' read -r source target <<< "${mapping}"

    if [[ ! -e "${source}" ]]; then
      log "Missing source file: ${source}"
      exit 1
    fi

    create_link "${source}" "${target}"
  done

  if [[ ${CREATED_BACKUP_DIR} -eq 1 ]]; then
    log "Backups stored in ${BACKUP_DIR}"
  else
    log "No existing files required backup"
  fi

  log "Done"
}

main "$@"
