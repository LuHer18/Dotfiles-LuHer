# Dotfiles LuHer

Practical dotfiles for a Ghostty + tmux + zsh + Starship + Aerospace workflow.

## What is included

- Ghostty config
- Aerospace config
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
| `config/aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` |
| `config/starship.toml` | `~/.config/starship.toml` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `zsh/.zshrc` | `~/.zshrc` |

## Recommended dependencies

- Ghostty
- Aerospace
- tmux
- zsh
- Starship
- Nerd Font
- Kitty (for `kitten icat` image rendering)

Install Aerospace with Homebrew:

```bash
brew install --cask nikitabobko/tap/aerospace
```

## Aerospace workspace layout

This setup starts with safe manual workspace control. App automation should be added later, one app at a time, after Aerospace is stable.

| Workspace | Purpose | Layout |
|---|---|---|
| 1 | Normal/shared use | Floating |
| 2 | Main development: Ghostty + VS Code/Cursor | Manual |
| 3 | Secondary development: IntelliJ or second project | Manual |
| 4 | Browser/API: Zen dev windows + Postman | Manual |
| 5 | Data/infra: Docker + DBeaver | Manual |
| 6 | Communication: Teams | Manual |

Workspace 1 is kept floating by default so it feels close to normal macOS behavior. Zen Browser is intentionally not moved automatically because it is used for both normal and development browsing. Move windows manually with `ctrl-alt-shift-<workspace>`.

Ghostty opens automatically in workspace 2 as the main development terminal. VS Code and IntelliJ open automatically in workspace 3 for code editing. Postman opens in workspace 4 for API testing. Docker Desktop and DBeaver open in workspace 5 for data and infrastructure.

Core shortcuts:

| Shortcut | Action |
|---|---|
| `ctrl-alt-1..6` | Switch workspace |
| `ctrl-alt-shift-1..6` | Move focused window to workspace |
| `ctrl-alt-h/j/k/l` | Focus tiled windows |
| `ctrl-alt-shift-h/j/k/l` | Move tiled windows |
| `ctrl-alt-enter` | Toggle Aerospace fullscreen |
| `ctrl-alt-space` | Toggle floating/tiling |
| `ctrl-alt-shift-enter` | Force focused window back to tiling |
| `ctrl-alt-minus` / `ctrl-alt-equal` | Resize focused tile |
| `ctrl-alt-r` | Balance tiled window sizes |

If a window gets stuck floating, focus it and press `ctrl-alt-shift-enter` to force it back into tiling, then `ctrl-alt-r` to balance sizes.

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
