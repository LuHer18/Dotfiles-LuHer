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

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first --git'
  alias la='eza -A --icons --group-directories-first'
  alias lt='eza --tree --level=2 --icons --group-directories-first'
else
  alias ll='ls -lah'
  alias la='ls -A'
fi

alias gs='git status --short --branch'
alias icat='kitten icat'

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

if [[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [[ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
