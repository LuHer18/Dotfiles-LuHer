#!/usr/bin/env python3
"""Terminal selector for dotfiles setup; UI is stderr and the CSV result is stdout."""

import argparse
import os
import select
import shutil
import sys
import termios
import tty
from dataclasses import dataclass


@dataclass(frozen=True)
class Choice:
    identifier: str
    description: str


def menu_choices(os_name: str) -> list[Choice]:
    choices = [
        Choice("ghostty", "Terminal moderno y configurable"),
        Choice("tmux", "Multiplexor de terminal"),
        Choice("herdr", "Multiplexor para sesiones con agentes de IA"),
        Choice("starship", "Prompt rápido y personalizable"),
        Choice("zsh", "Shell interactiva"),
        Choice("opencode", "Agente de programación de terminal"),
        Choice("pi", "Pi (opcional; +7 extensiones)"),
    ]
    if os_name == "Darwin":
        choices.append(Choice("aerospace", "AeroSpace: gestor de ventanas para macOS"))
    return choices


def display_os(os_name: str) -> str:
    return "macOS" if os_name == "Darwin" else os_name


def write_ui(line: str = "") -> None:
    print(line, file=sys.stderr, flush=True)


def clipped(line: str, width: int) -> str:
    if len(line) <= width:
        return line
    if width <= 1:
        return line[:width]
    return line[: width - 1] + "…"


def plain_menu(choices: list[Choice], os_name: str, arch: str) -> list[str]:
    """Use a numbered CSV prompt when the terminal cannot safely redraw."""
    write_ui(f"Dotfiles · {display_os(os_name)} · {arch}")
    for number, choice in enumerate(choices, start=1):
        write_ui(f"{number}) {choice.identifier} — {choice.description}")
    write_ui("Números separados por comas; Enter cancela:")
    answer = sys.stdin.readline().strip()
    if not answer:
        return []

    selected: list[str] = []
    try:
        numbers = [int(value.strip()) for value in answer.split(",")]
    except ValueError:
        write_ui("Selección inválida; no se realizaron cambios.")
        return []
    for number in numbers:
        if number < 1 or number > len(choices):
            write_ui("Selección inválida; no se realizaron cambios.")
            return []
        identifier = choices[number - 1].identifier
        if identifier not in selected:
            selected.append(identifier)
    return selected


def read_key(fd: int) -> bytes:
    key = os.read(fd, 1)
    if key != b"\x1b":
        return key
    if not select.select([fd], [], [], 0.05)[0]:
        return key
    sequence = key + os.read(fd, 1)
    if sequence != b"\x1b[" or not select.select([fd], [], [], 0.05)[0]:
        return sequence
    return sequence + os.read(fd, 1)


def visual_menu(
    choices: list[Choice], os_name: str, arch: str, width: int
) -> list[str]:
    """Redraw a checkbox selector and always restore terminal attributes."""
    fd = sys.stdin.fileno()
    original = termios.tcgetattr(fd)
    selected: set[int] = set()
    focus = 0
    cursor_hidden = False
    try:
        tty.setraw(fd)
        sys.stderr.write("\x1b[?25l")
        sys.stderr.flush()
        cursor_hidden = True
        while True:
            lines = [
                f"Dotfiles · {display_os(os_name)} · {arch}",
                "Espacio marca; flechas recorren; Enter confirma; Esc cancela.",
            ]
            for index, choice in enumerate(choices):
                marker = "x" if index in selected else " "
                pointer = ">" if index == focus else " "
                lines.append(
                    f"{pointer} [{marker}] {choice.identifier}: {choice.description}"
                )
            screen = "\n".join(clipped(line, width) for line in lines)
            sys.stderr.write("\x1b[H\x1b[2J" + screen)
            sys.stderr.flush()

            key = read_key(fd)
            if key in (b"\x03", b"\x04", b"\x1b"):
                return []
            if key in (b"\r", b"\n"):
                return [
                    choices[index].identifier
                    for index in range(len(choices))
                    if index in selected
                ]
            if key == b" ":
                if focus in selected:
                    selected.remove(focus)
                else:
                    selected.add(focus)
            elif key == b"\x1b[A":
                focus = (focus - 1) % len(choices)
            elif key == b"\x1b[B":
                focus = (focus + 1) % len(choices)
    except KeyboardInterrupt:
        return []
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, original)
        # Darwin keeps PENDIN after raw mode until the input queue is flushed.
        termios.tcflush(fd, termios.TCIFLUSH)
        if cursor_hidden:
            sys.stderr.write("\x1b[?25h")
            sys.stderr.flush()


def select_choices(os_name: str, arch: str) -> list[str]:
    choices = menu_choices(os_name)
    terminal = shutil.get_terminal_size(fallback=(80, 24))
    term = os.environ.get("TERM", "")
    # No color is emitted. TERM=dumb, an unset TERM, and narrow terminals avoid ANSI redraws.
    if term in ("", "dumb") or terminal.columns < 30 or not sys.stdin.isatty():
        return plain_menu(choices, os_name, arch)
    return visual_menu(choices, os_name, arch, terminal.columns)


def main() -> int:
    parser = argparse.ArgumentParser(description="Interactive dotfiles selector")
    parser.add_argument("--os", required=True, dest="os_name")
    parser.add_argument("--arch", required=True)
    arguments = parser.parse_args()
    selected = select_choices(arguments.os_name, arguments.arch)
    sys.stdout.write(",".join(selected) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
