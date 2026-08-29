#!/usr/bin/env python3

import fcntl
import json
import os
from pathlib import Path
import secrets
import shlex
import signal
import subprocess
import sys
import time


SCRIPT_PATH = Path(__file__).resolve()
STATE_DIR = Path(os.environ.get("TMPDIR", "/tmp")) / f"dotfiles-luher-sketchybar-media-{os.getuid()}"
STATE_FILE = STATE_DIR / "watcher.json"
LOCK_FILE = STATE_DIR / "watcher.lock"
MEDIA_CONTROL = "/opt/homebrew/bin/media-control"
SKETCHYBAR = "/opt/homebrew/bin/sketchybar"


def process_matches(pid, token):
    try:
        result = subprocess.run(
            ["/bin/ps", "-ww", "-p", str(pid), "-o", "command="],
            check=True,
            capture_output=True,
            text=True,
        )
        arguments = shlex.split(result.stdout.strip())
    except (OSError, subprocess.CalledProcessError, ValueError):
        return False

    expected = [str(SCRIPT_PATH), "run", token]
    return any(arguments[index : index + 3] == expected for index in range(len(arguments) - 2))


def load_state():
    try:
        state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return int(state["pid"]), str(state["token"])
    except (OSError, ValueError, KeyError, TypeError):
        return None


def save_state(pid, token):
    temporary = STATE_FILE.with_suffix(f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps({"pid": pid, "token": token}) + "\n", encoding="utf-8")
    os.replace(temporary, STATE_FILE)


def normalized_metadata(raw):
    try:
        document = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return "stopped", "", ""

    if not isinstance(document, dict):
        return "stopped", "", ""

    payload = document.get("payload", document)
    if not isinstance(payload, dict):
        return "stopped", "", ""

    artist = payload.get("artist") if isinstance(payload.get("artist"), str) else ""
    title = payload.get("title") if isinstance(payload.get("title"), str) else ""
    artist = artist.strip()
    title = title.strip()
    playing = payload.get("playing") is True

    if not playing or (not artist and not title):
        return "stopped", "", ""
    return "playing", artist, title


def emit(raw):
    state, artist, title = normalized_metadata(raw)
    subprocess.run(
        [
            SKETCHYBAR,
            "--trigger",
            "media_control_update",
            f"STATE={state}",
            f"ARTIST={artist}",
            f"TITLE={title}",
        ],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def snapshot():
    try:
        result = subprocess.run(
            [MEDIA_CONTROL, "get", "--no-artwork"],
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
        emit(result.stdout)
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        emit("")


def start():
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    with LOCK_FILE.open("a+", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        current = load_state()
        if current and process_matches(*current):
            snapshot()
            return

        token = secrets.token_hex(16)
        with (STATE_DIR / "watcher.log").open("ab", buffering=0) as log:
            process = subprocess.Popen(
                [sys.executable, str(SCRIPT_PATH), "run", token],
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=log,
                start_new_session=True,
            )
        save_state(process.pid, token)


def run(token):
    stopping = False
    child = None

    def stop(_signum, _frame):
        nonlocal stopping
        stopping = True
        if child and child.poll() is None:
            child.terminate()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    try:
        while not stopping:
            try:
                child = subprocess.Popen(
                    [MEDIA_CONTROL, "stream", "--no-artwork", "--no-diff", "--debounce=100"],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    bufsize=1,
                )
                if child.stdout:
                    for line in child.stdout:
                        if stopping:
                            break
                        emit(line)
                child.wait(timeout=2)
            except (OSError, subprocess.TimeoutExpired):
                if child and child.poll() is None:
                    child.kill()
                    child.wait()
            if not stopping:
                time.sleep(2)
    finally:
        current = load_state()
        if current == (os.getpid(), token):
            STATE_FILE.unlink(missing_ok=True)


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "start":
        start()
    elif len(sys.argv) == 2 and sys.argv[1] == "snapshot":
        snapshot()
    elif len(sys.argv) == 3 and sys.argv[1] == "emit-json":
        emit(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "run":
        run(sys.argv[2])
    else:
        raise SystemExit("usage: media_watcher.py start|snapshot|emit-json JSON")


if __name__ == "__main__":
    main()
