export EDITOR="nvim"
export VISUAL="nvim"

DOTFILES_ZSH_DIR="${${(%):-%N}:A:h}"
DOTFILES_REPO_DIR="${DOTFILES_ZSH_DIR:h}"

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
alias avatar="cat ${DOTFILES_REPO_DIR}/assets/avatar.ansi"

if command -v kitten >/dev/null 2>&1; then
  alias icat='kitten icat'
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

for plugin in \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -r "$plugin" ]] && { source "$plugin"; break; }
done
for plugin in \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [[ -r "$plugin" ]] && { source "$plugin"; break; }
done

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
export PATH="$HOME/.local/bin:$PATH"

    # pnpm
    if [[ -n "${PNPM_HOME:-}" ]]; then
      : # honor an explicitly configured location
    elif [[ "$OSTYPE" == darwin* ]]; then
      export PNPM_HOME="$HOME/Library/pnpm"
    else
      export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
    fi
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
