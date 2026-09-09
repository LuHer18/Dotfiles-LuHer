# Portable Pi snapshot

This directory is a safe, non-activating snapshot of selected Pi preferences, the Catppuccin Mocha theme, and the exact package versions currently installed on the source machine. It is not wired into the installer and does not replace or activate live Pi settings.

## Deliberate restore

Review the files first, then merge only the settings you want into `~/.pi/agent/settings.json` and copy the theme to `~/.pi/agent/themes/` deliberately. Preserve any local settings while merging; do not overwrite the live file wholesale unless that is intentional. Install the listed packages separately only after reviewing their code and confirming the pinned versions remain appropriate. Restart Pi or reload its resources as appropriate.

## Included

- `settings.json`: selected theme, skill-command preference, and pinned package specs.
- `themes/catppuccin-mocha.json`: the selected custom theme.

## Excluded private or machine-specific data

This snapshot intentionally excludes authentication and session data (`auth.json`, `sessions/`), MCP configuration, private/custom model and provider configuration, account-specific startup model choices, trust decisions, runtime metadata, managed package assets, and absolute private paths. No live settings are changed by this repository.
