# Dotfiles LuHer

Practical dotfiles for a lightweight Ghostty + tmux + zsh + Starship + Aerospace workflow, with Herdr available as an opt-in agent-focused alternative to tmux.

## What is included

- Ghostty config
- Aerospace config
- SketchyBar config with SbarLua and Aerospace workspaces
- Starship prompt config
- tmux config
- Herdr config (optional tmux alternative)
- zsh config
- install script with backups, dry-run support, and safe symlink replacement

Kitty is **not** the main terminal here. It is included only as a recommended companion tool for image rendering with `kitten icat`.

## Quick install

1. Clone this repository.
2. Review the configs before linking them.
3. Preview the installer if you want a safe check first:

```bash
./install.sh --dry-run
```

4. Run the installer:

```bash
./install.sh
```

The script will:

- create missing target directories
- back up any existing target file or symlink
- skip targets that are already linked correctly
- replace targets with symlinks to this repository

This is the legacy installer. It deploys only the targets explicitly listed in `install.sh`; it does not deploy the SketchyBar mapping declared in `dotfiles.json`.

Backups are stored in:

```bash
~/.dotfiles-backups/<timestamp>/
```

Restore is manual by design so nothing is overwritten automatically behind your back:

```bash
rm ~/.zshrc
mv ~/.dotfiles-backups/<timestamp>/.zshrc ~/.zshrc
```

Repeat the same pattern for any other managed target: remove the managed symlink first, then move the backup into place.

## Declared targets

These mappings are declared in `dotfiles.json`. The legacy installer currently deploys all of them except SketchyBar.

| Repository file | Target | Legacy installer |
|---|---|---|
| `config/ghostty/config` | `~/.config/ghostty/config` | Yes |
| `config/aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` | Yes |
| `config/sketchybar/` | `~/.config/sketchybar/` | No |
| `config/herdr/config.toml` | `~/.config/herdr/config.toml` | Yes |
| `config/opencode/tui.json` | `~/.config/opencode/tui.json` | Yes |
| `config/starship.toml` | `~/.config/starship.toml` | Yes |
| `tmux/scripts/` | `~/.config/tmux/scripts/` | Yes |
| `tmux/.tmux.conf` | `~/.tmux.conf` | Yes |
| `zsh/.zshrc` | `~/.zshrc` | Yes |

## Dependencies and optional features

### Core tools

- Ghostty
- Aerospace
- SketchyBar with the SbarLua module
- tmux
- Herdr (optional)
- zsh
- Starship
- JetBrainsMono Nerd Font or another Nerd Font
- `sketchybar-app-font` and its generated application map

### Optional command-line integrations used by `zsh/.zshrc`

These are optional. The shell config checks for them before enabling anything.

| Tool | Purpose |
|---|---|
| `eza` | Better `ls`, `ll`, `la`, and `lt` aliases |
| `fnm` | Auto-load Node.js versions on directory change |
| `zoxide` | Smarter directory jumping |
| `atuin` | Better shell history |
| `zsh-autosuggestions` | Inline command suggestions |
| `zsh-syntax-highlighting` | Shell syntax highlighting |
| Kitty | Optional `kitten icat` image rendering via the `icat` alias when `kitten` is installed |

Install Aerospace with Homebrew:

```bash
brew install --cask nikitabobko/tap/aerospace
```

Install Herdr with Homebrew:

```bash
brew install herdr
```

### SketchyBar activation

The SketchyBar config requires SketchyBar, SbarLua at `~/.local/share/sketchybar_lua/`, Aerospace, the Homebrew core `media-control` formula, and [`kvndrsslr/sketchybar-app-font`](https://github.com/kvndrsslr/sketchybar-app-font). Install those prerequisites manually from their official documentation; this repository does not install packages or application fonts.

Build `sketchybar-app-font` with its documented `pnpm install` and `pnpm run build` commands. Install the generated assets outside this repository at these stable paths:

```text
~/Library/Fonts/sketchybar-app-font.ttf
~/.local/share/sketchybar-app-font/icon_map.sh
```

Do not run the upstream installer against this active configuration: `~/.config/sketchybar` is a repository symlink, so its default map destination would add generated third-party files to the repository. The small bundled `app_icon.sh` helper reads the external maintained map and returns the font's `:default:` glyph when an application is unknown or the map cannot produce a valid ligature.

The mapping is declared in `dotfiles.json`, but `install.sh` does not deploy it and the safe repository manager is not runnable yet. Do not bypass its backup and safety policy with ad hoc linking commands. Wait for that workflow to become available, or use it once available, before deploying or activating this configuration. AeroSpace must read the updated `aerospace.toml` before workspace-change events are emitted.

The bar uses a transparent canvas with compact, semi-transparent status pills. Its colors follow the bundled Catppuccin Mocha palette selected by `config/ghostty/config`; translucent surfaces add alpha without changing the source RGB values. Workspaces 1–5, the front application, and a capped `media-control` Now Playing label are on the left in that order. The front application shows its `sketchybar-app-font` icon immediately before the unchanged application name, follows the focused AeroSpace workspace, and hides both icon and label when that workspace is empty. The chevron expands or collapses additional workspaces discovered with `aerospace list-workspaces --all`; each revealed workspace remains directly selectable. If a hidden additional workspace becomes focused, the list expands automatically so that focus remains visible. CPU, RAM, root-disk usage, interactive volume, battery, passive Wi-Fi connectivity, and the Spanish date and time are on the right. The Wi-Fi item only reports `Conectado` or `Sin conexión`; it has no click action, does not inspect the SSID, and does not require Screen Recording permission. Left-clicking volume toggles mute without replacing the prior level, while scrolling changes output volume in five-point steps. Now Playing uses one configuration-owned `media-control stream` watcher and hides paused or incomplete metadata. Updates use native events where available and bounded asynchronous polling for metrics that require current system state.

## Aerospace workspace layout

This setup is still conservative, but it already includes a small amount of app automation for the main development workflow.

Tiled windows use 8px inner and outer gaps for a small visual separation between applications.

| Workspace | Purpose | Actual behavior |
|---|---|---|
| 1 | Normal/shared use | Floating default |
| 2 | Main terminal | Ghostty auto-moves here |
| 3 | Code editors | VS Code and IntelliJ auto-move here |
| 4 | Browser/API work | Postman auto-moves here; browsers stay manual |
| 5 | Data/infra | Docker Desktop and DBeaver auto-move here |
| 6 | Communication or overflow | Manual |

Workspace 1 is kept floating by default so it feels close to normal macOS behavior. Zen Browser is intentionally not moved automatically because it is used for both normal and development browsing. Move windows manually with `ctrl-alt-shift-<workspace>` when needed.

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

## tmux behavior

- Prefix is `Ctrl-a`
- Mouse mode is enabled
- Copy-mode uses Vim keys
- Mouse selection in copy-mode copies the selected text to `pbcopy` on macOS
- New panes and windows start in the current pane directory
- Status scripts show window name, Git branch, CPU, RAM, and time

The tmux status helpers are installed under `~/.config/tmux/scripts`, so the status line does not depend on a hard-coded repository location. The bundled `pbcopy` clipboard integration is macOS-specific.

## Herdr behavior (optional)

Herdr is an opt-in alternative for agent-focused sessions; tmux remains installed and unchanged. Start one multiplexer per terminal: **do not nest tmux and Herdr**. Nested multiplexers conflict on prefix handling, and Herdr cannot detect agents running behind a tmux process inside a Herdr pane.

The managed config uses the built-in Kanagawa theme with the current tmux status colors, starts `/bin/zsh` as a macOS login shell, and inherits the active pane directory for new panes and tabs.

| Key | Action |
|---|---|
| `Ctrl-a c` | Create tab |
| `Ctrl-a n` / `Ctrl-a p` | Next / previous tab |
| `Ctrl-a h/j/k/l` | Focus left / down / up / right pane |
| `Ctrl-a v` | Split side by side |
| `Ctrl-a d` | Split stacked |
| `Ctrl-a r` | Reload Herdr config |
| `Ctrl-a Shift-r` | Enter resize mode |

Herdr's OpenCode integration is installed separately with `herdr integration install opencode`. It adds only `~/.config/opencode/plugins/herdr-agent-state.js`; it reports OpenCode lifecycle state and session identity for OpenCode processes running inside Herdr and does not modify `~/.config/opencode/opencode.json`.

## Ghostty behavior

- Ghostty is the main terminal for this repo
- `shell-integration = zsh`
- `copy-on-select = true`
- `Command+Shift+O` opens the tab overview
- Background blur and a slightly transparent window are enabled

## zsh behavior

- zsh is the only shell targeted here
- `avatar` prints the repository ANSI avatar
- `icat` is available only if Kitty tools are installed
- Optional integrations enable themselves only when their command or file exists

## Non-destructive checks

Run the repo check script any time after editing configs:

```bash
./scripts/check.sh
```

It runs syntax/config validation only. It does not install, relink, reload, or mutate your live setup.

## Image rendering with Kitty tools

Even if Ghostty is your main terminal, you can keep Kitty installed for its graphics tooling.

Example:

```bash
kitten icat image.png
```

## Notes

- The zsh config stays compatible with zsh only. No fish setup is included.
- The prompt shows current directory, Git branch, Git status, and command duration.
- The configs avoid secrets and reduce machine-specific absolute paths where practical.

## Updating

After changing files in this repository, re-run:

```bash
./install.sh
```

For a safe preview first:

```bash
./install.sh --dry-run
```
