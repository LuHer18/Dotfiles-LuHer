export EDITOR="nvim"
export VISUAL="nvim"

setopt AUTO_CD
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

autoload -Uz compinit
compinit

bindkey -e

alias ll='ls -lah'
alias la='ls -A'
alias gs='git status --short --branch'
alias icat='kitten icat'

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
