#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail(){ echo "FAIL: $1" >&2; exit 1; }
h=$(mktemp -d); out=$(HOME="$h" DOTFILES_TEST_OS=Linux DOTFILES_OS_RELEASE=<(printf 'ID=ubuntu\nVERSION_ID=24.04\n') DOTFILES_APP_SELECT='ghostty tmux' DOTFILES_DRY_RUN=1 PATH="/usr/bin:/bin" bash "$ROOT/scripts/install-apps.sh" --yes 2>&1) && fail 'unsupported Ghostty accepted' || :
[[ "$out" == *'manual-only'* ]] || fail 'missing Ghostty guide'
marker="$h/marker"; printf '#!/usr/bin/env bash\nprintf called >>"$LOG"\n' >"$h/brew"; chmod +x "$h/brew"; out=$(HOME="$h" LOG="$marker" DOTFILES_TEST_OS=Darwin DOTFILES_APP_SELECT='herdr' DOTFILES_DRY_RUN=1 PATH="$h:/usr/bin:/bin" bash "$ROOT/scripts/install-apps.sh" --yes 2>&1) || fail 'dry run failed'
[[ "$out" == *'DRY RUN'* ]] || fail 'dry run did not plan'
[[ ! -e "$marker" ]] || fail 'dry run mutated state'
printf 'install-apps tests passed\n'
