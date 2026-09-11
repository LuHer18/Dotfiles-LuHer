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

MIN_VISUAL_WIDTH = 56
MIN_VISUAL_HEIGHT = 10
MAX_PANEL_WIDTH = 84
ACCENT = "\x1b[38;5;183m"
MUTED = "\x1b[38;5;110m"
FOCUS = "\x1b[48;5;60m\x1b[38;5;230m"
RESET = "\x1b[0m"


@dataclass(frozen=True)
class Choice:
    identifier: str
    label: str
    description: str


def menu_choices(os_name: str) -> list[Choice]:
    choices = [
        Choice("ghostty", "Ghostty", "Terminal moderno y configurable"),
        Choice("tmux", "tmux", "Multiplexor de terminal"),
        Choice("herdr", "Herdr", "Multiplexor para sesiones con agentes de IA"),
        Choice("starship", "Starship", "Prompt rápido y personalizable"),
        Choice("zsh", "Zsh", "Shell interactiva"),
        Choice("opencode", "OpenCode", "Agente de programación de terminal"),
        Choice("pi", "Pi", "Pi (opcional; +7 extensiones)"),
        Choice("atuin", "Atuin", "Historial de shell sincronizable"),
        Choice("zoxide", "Zoxide", "Navegación rápida entre directorios"),
        Choice("eza", "eza", "Listado moderno de archivos"),
        Choice("fnm", "fnm", "Gestor rápido de versiones de Node.js"),
        Choice(
            "zsh-autosuggestions",
            "Autosugerencias Zsh",
            "Sugerencias mientras escribes en Zsh",
        ),
        Choice(
            "zsh-syntax-highlighting",
            "Resaltado Zsh",
            "Colores de sintaxis para Zsh",
        ),
        Choice("neovim", "Neovim", "Editor extensible (ejecutable: nvim)"),
    ]
    if os_name == "Darwin":
        choices.append(
            Choice("aerospace", "AeroSpace", "Gestor de ventanas para macOS")
        )
    return choices


def display_os(os_name: str) -> str:
    return "macOS" if os_name == "Darwin" else os_name


def write_ui(line: str = "") -> None:
    print(line, file=sys.stderr, flush=True)


def clipped(line: str, width: int) -> str:
    if width <= 0:
        return ""
    if len(line) <= width:
        return line
    if width == 1:
        return "…"
    return line[: width - 1] + "…"


def supports_color(environment=None) -> bool:
    environment = os.environ if environment is None else environment
    return (
        bool(environment.get("TERM"))
        and environment.get("TERM") != "dumb"
        and "NO_COLOR" not in environment
    )


def plain_lines(
    choices: list[Choice], os_name: str, arch: str, width: int
) -> list[str]:
    """Return a bounded, non-redrawing fallback for small or basic terminals."""
    lines = [clipped(f"Dotfiles · LuHer — {display_os(os_name)} / {arch}", width)]
    lines.extend(
        clipped(f"{number}) {choice.label} — {choice.description}", width)
        for number, choice in enumerate(choices, start=1)
    )
    lines.append(clipped("Números separados por comas; Enter cancela:", width))
    return lines


def plain_menu(choices: list[Choice], os_name: str, arch: str, width: int) -> list[str]:
    """Use a numbered CSV prompt when the terminal cannot safely redraw."""
    for line in plain_lines(choices, os_name, arch, width):
        write_ui(line)
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


def panel_line(content: str, inner_width: int, color: str = "") -> str:
    text = clipped(content, inner_width).ljust(inner_width)
    if not color:
        return f"| {text} |"
    return f"{ACCENT}|{RESET} {color}{text}{RESET} {ACCENT}|{RESET}"


def visible_range(total: int, focus: int, height: int) -> tuple[int, int]:
    """Return the focus viewport for the compact panel."""
    capacity = max(1, height - 8)
    start = min(max(0, focus - capacity + 1), max(0, total - capacity))
    return start, min(total, start + capacity)


def render_menu(
    choices: list[Choice],
    os_name: str,
    arch: str,
    width: int,
    *,
    focus: int,
    selected: set[int],
    color: bool,
    height: int = 24,
) -> str:
    """Build one panel frame using CRLF for raw-terminal-safe line starts."""
    panel_width = min(MAX_PANEL_WIDTH, max(MIN_VISUAL_WIDTH, width - 2))
    inner_width = panel_width - 4
    indent = " " * max(0, (width - panel_width) // 2)
    accent = ACCENT if color else ""
    muted = MUTED if color else ""

    lines = [
        f"{accent}+{'-' * (panel_width - 2)}+{RESET if color else ''}",
        panel_line("Dotfiles · LuHer".center(inner_width), inner_width, accent),
        panel_line(
            f"{display_os(os_name)} / {arch}".center(inner_width), inner_width, muted
        ),
        panel_line("-" * inner_width, inner_width, accent),
    ]
    label_width = 22
    start, end = visible_range(len(choices), focus, height)
    for index in range(start, end):
        choice = choices[index]
        marker = "x" if index in selected else " "
        pointer = ">" if index == focus else " "
        row = f"{pointer} [{marker}] {choice.label:<{label_width}} {choice.description}"
        lines.append(
            panel_line(row, inner_width, FOCUS if color and index == focus else "")
        )
    status = f"selected {len(selected)}"
    if end - start < len(choices):
        status += f" · showing {start + 1}-{end} of {len(choices)}"
    lines.extend(
        [
            panel_line("-" * inner_width, inner_width, accent),
            panel_line(
                f"{status}  ·  ↑↓ move  Space toggle  Enter confirm  Esc cancel",
                inner_width,
                muted,
            ),
            f"{accent}+{'-' * (panel_width - 2)}+{RESET if color else ''}",
        ]
    )
    return "\r\n".join(indent + line for line in lines)


def visual_height(choices: list[Choice]) -> int:
    # The viewport scrolls rows, so the compact frame needs only one row.
    return MIN_VISUAL_HEIGHT


def can_use_visual(terminal: os.terminal_size, choices: list[Choice]) -> bool:
    term = os.environ.get("TERM", "")
    return (
        bool(term)
        and term != "dumb"
        and sys.stdin.isatty()
        and sys.stderr.isatty()
        and terminal.columns >= MIN_VISUAL_WIDTH
        and terminal.lines >= visual_height(choices)
    )


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


def visual_menu(choices: list[Choice], os_name: str, arch: str) -> list[str]:
    """Redraw a selector and restore terminal state on success, resize, or error."""
    fd = sys.stdin.fileno()
    original = termios.tcgetattr(fd)
    selected: set[int] = set()
    focus = 0
    raw_enabled = False
    cursor_hidden = False
    use_plain_fallback = False
    try:
        # Mark this before setraw so a partially failed tcsetattr is restored too.
        raw_enabled = True
        tty.setraw(fd)
        sys.stderr.write("\x1b[?25l")
        sys.stderr.flush()
        cursor_hidden = True
        while True:
            terminal = shutil.get_terminal_size(fallback=(80, 24))
            if not can_use_visual(terminal, choices):
                use_plain_fallback = True
                break
            screen = render_menu(
                choices,
                os_name,
                arch,
                terminal.columns,
                focus=focus,
                selected=selected,
                color=supports_color(),
                height=terminal.lines,
            )
            # setraw() clears OPOST/ONLCR. CRLF is therefore intentional: a bare
            # LF would retain its previous column and make each row stair-step.
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
        if raw_enabled:
            # Emit this before restoring OPOST: explicit CRLF cannot become CRCRLF.
            try:
                if cursor_hidden:
                    sys.stderr.write("\x1b[?25h\r\n")
                    sys.stderr.flush()
            finally:
                try:
                    termios.tcsetattr(fd, termios.TCSADRAIN, original)
                finally:
                    # Darwin can retain PENDIN after raw mode until input is flushed.
                    termios.tcflush(fd, termios.TCIFLUSH)
    if use_plain_fallback:
        terminal = shutil.get_terminal_size(fallback=(80, 24))
        return plain_menu(choices, os_name, arch, terminal.columns)
    return []


def select_choices(os_name: str, arch: str) -> list[str]:
    choices = menu_choices(os_name)
    terminal = shutil.get_terminal_size(fallback=(80, 24))
    if not can_use_visual(terminal, choices):
        return plain_menu(choices, os_name, arch, terminal.columns)
    return visual_menu(choices, os_name, arch)


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
