#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BINARY=${1:-"$ROOT/tui/bin/dotfiles-tui"}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$BINARY" ]] || fail "missing executable TUI binary: $BINARY"

PYTHONDONTWRITEBYTECODE=1 python3 -B - "$BINARY" "$ROOT" <<'PY'
import fcntl
import os
import pty
import re
import select
import struct
import subprocess
import sys
import tempfile
import termios
import time

binary = sys.argv[1]
root = sys.argv[2]


def run_pty(arguments, keys, environment):
    master, slave = pty.openpty()
    columns = int(environment.get("COLUMNS", "80"))
    lines = int(environment.get("LINES", "24"))
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", lines, columns, 0, 0))
    before = termios.tcgetattr(slave)
    env = os.environ.copy()
    env.update(environment)
    process = subprocess.Popen(
        [binary, *arguments],
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=slave,
        env=env,
    )
    chunks = []
    deadline = time.time() + 5
    while time.time() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            chunks.append(os.read(master, 4096))
            break
    else:
        process.kill()
        raise AssertionError("TUI did not draw")
    os.write(master, keys)
    while process.poll() is None and time.time() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            try:
                chunks.append(os.read(master, 4096))
            except OSError:
                break
    if process.poll() is None:
        process.kill()
        raise AssertionError("TUI timed out")
    process.wait(timeout=1)
    while True:
        try:
            if not select.select([master], [], [], 0)[0]:
                break
            chunk = os.read(master, 4096)
            if not chunk:
                break
            chunks.append(chunk)
        except OSError:
            break
    after = termios.tcgetattr(slave)
    os.close(master)
    os.close(slave)
    return process.returncode, process.stdout.read(), b"".join(chunks), before, after


visual = run_pty(
    ["--os", "Darwin", "--arch", "arm64"],
    b"\x1b[B \r",
    {"TERM": "xterm-256color", "COLUMNS": "80", "LINES": "24"},
)
if visual[0] != 0 or visual[1] != b"tmux\n":
    raise AssertionError("visual result: %r" % (visual,))
if b"Dotfiles \xc2\xb7 LuHer" not in visual[2] or b"AeroSpace" not in visual[2]:
    raise AssertionError("visual UI missed Darwin choices")
if b"\x1b[?1049" in visual[2]:
    raise AssertionError("visual TUI used the alternate screen")

def assert_terminal_restored(name, result):
    if result[3] != result[4]:
        raise AssertionError(
            "%s changed terminal attributes: before=%r after=%r" % (name, result[3], result[4])
        )


for columns, lines in ((80, 24), (56, 18), (150, 20)):
    visual_environment = {
        "TERM": "xterm-256color",
        "COLUMNS": str(columns),
        "LINES": str(lines),
    }
    last_tool = run_pty(
        ["--os", "Linux", "--arch", "x86_64"],
        b"\x1b[B" * 13 + b" \r",
        visual_environment,
    )
    if last_tool[0] != 0 or last_tool[1] != b"neovim\n":
        raise AssertionError("last shell-tool result at %dx%d: %r" % (columns, lines, last_tool))
    assert_terminal_restored("confirm at %dx%d" % (columns, lines), last_tool)

    cancel = run_pty(
        ["--os", "Linux", "--arch", "x86_64"],
        b"\x1b",
        visual_environment,
    )
    if cancel[0] != 0 or cancel[1] != b"\n":
        raise AssertionError("cancel result at %dx%d: %r" % (columns, lines, cancel))
    if b"AeroSpace" in cancel[2]:
        raise AssertionError("Linux UI offered AeroSpace")
    assert_terminal_restored("cancel at %dx%d" % (columns, lines), cancel)

for key in (b"\x03", b"\x04"):
    interrupted = run_pty(
        ["--os", "Linux", "--arch", "x86_64"],
        key,
        {"TERM": "xterm-256color", "COLUMNS": "80", "LINES": "24"},
    )
    if interrupted[0] != 0 or interrupted[1] != b"\n":
        raise AssertionError("interrupt result: %r" % (interrupted,))

no_color = run_pty(
    ["--os", "Linux", "--arch", "x86_64"],
    b"\x1b",
    {"TERM": "xterm-256color", "COLUMNS": "80", "LINES": "24", "NO_COLOR": "1"},
)
if re.search(rb"\x1b\[[0-9;]*m", no_color[2]):
    raise AssertionError("NO_COLOR emitted SGR styling")

dumb = run_pty(
    ["--os", "Linux", "--arch", "x86_64"],
    b"2,3\n",
    {"TERM": "dumb", "COLUMNS": "40", "LINES": "8", "NO_COLOR": "1"},
)
if dumb[0] != 0 or dumb[1] != b"tmux,herdr\n":
    raise AssertionError("dumb result: %r" % (dumb,))
if b"\x1b" in dumb[2]:
    raise AssertionError("dumb fallback emitted control sequences")
assert_terminal_restored("40x12 plain fallback", dumb)

with tempfile.TemporaryDirectory() as temporary:
    release_file = os.path.join(temporary, "os-release")
    with open(release_file, "w", encoding="utf-8") as stream:
        stream.write("ID=ubuntu\n")
    launcher_env = {
        **os.environ,
        "DOTFILES_OS": "Linux",
        "DOTFILES_OS_RELEASE": release_file,
        "DOTFILES_TUI_BIN": os.path.join(temporary, "missing-tui"),
        "HOME": temporary,
    }
    master, slave = pty.openpty()
    launcher = subprocess.Popen(
        ["bash", os.path.join(root, "dotfiles"), "setup", "--dry-run"],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        env=launcher_env,
    )
    os.close(slave)
    launcher_chunks = []
    deadline = time.time() + 5
    while launcher.poll() is None and time.time() < deadline:
        if select.select([master], [], [], 0.1)[0]:
            try:
                launcher_chunks.append(os.read(master, 4096))
            except OSError:
                break
    launcher.wait(timeout=1)
    os.close(master)
    launcher_ui = b"".join(launcher_chunks)
    if launcher.returncode == 0 or b"DOTFILES_TUI_BIN must name an executable file" not in launcher_ui:
        raise AssertionError("invalid launcher override fell back: %r" % (launcher_ui,))

    bypass = subprocess.run(
        ["bash", os.path.join(root, "dotfiles"), "setup", "--select", "tmux", "--configs-only", "--dry-run"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=launcher_env,
        check=False,
    )
    if bypass.returncode != 0 or b"tmux" not in bypass.stdout:
        raise AssertionError("--select did not bypass the TUI: %r" % (bypass,))

invalid = subprocess.run(
    [binary, "--os", "Darwin"],
    stdin=subprocess.DEVNULL,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    env={**os.environ, "TERM": "dumb"},
    check=False,
)
if invalid.returncode == 0 or invalid.stdout or b"--os and --arch are required" not in invalid.stderr:
    raise AssertionError("argument error contaminated stdout: %r" % (invalid,))
PY

printf 'tui tests passed\n'
