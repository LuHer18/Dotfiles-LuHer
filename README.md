# Dotfiles LuHer

Practical dotfiles for a Ghostty + tmux + zsh + Starship workflow.

## What is included

- Ghostty config
- Starship prompt config
- tmux config
- zsh config
- install script with backups and safe symlink replacement

Kitty is **not** the main terminal here. It is included only as a recommended companion tool for image rendering with `kitten icat`.

## Quick install

1. Clone this repository.
2. Review the configs before linking them.
3. Run the installer:

```bash
./install.sh
```

The script will:

- create missing target directories
- back up any existing target file or symlink
- replace targets with symlinks to this repository

Backups are stored in:

```bash
~/.dotfiles-backups/<timestamp>/
```

## Managed targets

| Repository file | Installed target |
|---|---|
| `config/ghostty/config` | `~/.config/ghostty/config` |
| `config/starship.toml` | `~/.config/starship.toml` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `zsh/.zshrc` | `~/.zshrc` |

## Recommended dependencies

- Ghostty
- tmux
- zsh
- Starship
- Nerd Font
- Kitty (for `kitten icat` image rendering)

## Image rendering with Kitty tools

Even if Ghostty is your main terminal, you can keep Kitty installed for its graphics tooling.

Example:

```bash
kitten icat image.png
```

## Notes

- The zsh config stays compatible with zsh only. No fish setup is included.
- The prompt shows current directory, Git branch, Git status, and command duration.
- The configs avoid secrets and machine-specific absolute paths.

## Updating

After changing files in this repository, re-run:

```bash
./install.sh
```
