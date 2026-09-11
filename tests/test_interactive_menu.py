#!/usr/bin/env python3
"""Regression tests for the interactive selector's terminal rendering contract."""

import importlib.util
import os
import pty
import select
import subprocess
import sys
import termios
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MENU_PATH = ROOT / "scripts" / "interactive_menu.py"
spec = importlib.util.spec_from_file_location("interactive_menu", MENU_PATH)
assert spec and spec.loader
menu = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = menu
spec.loader.exec_module(menu)


class RawScreen:
    """Small terminal model where LF advances down without an implicit CR.

    tty.setraw() disables OPOST, so this deliberately does *not* normalize LF.
    It catches output that looks fine only when a terminal's cooked output mode
    silently turns LF into CRLF.
    """

    def __init__(self, width: int):
        self.width = width
        self.x = 0
        self.y = 0
        self.cells: dict[int, dict[int, str]] = {}

    def feed(self, data: str) -> None:
        index = 0
        while index < len(data):
            char = data[index]
            if char == "\x1b":
                end = index + 1
                if end < len(data) and data[end] == "[":
                    end += 1
                    while end < len(data) and not ("@" <= data[end] <= "~"):
                        end += 1
                    command = data[end] if end < len(data) else ""
                    if command == "H":
                        self.x = self.y = 0
                    index = end + 1
                    continue
            if char == "\r":
                self.x = 0
            elif char == "\n":
                self.y += 1
            elif ord(char) >= 32:
                if self.x < self.width:
                    self.cells.setdefault(self.y, {})[self.x] = char
                self.x += 1
            index += 1

    def lines(self) -> list[str]:
        if not self.cells:
            return []
        return [
            "".join(
                self.cells.get(row, {}).get(column, " ") for column in range(self.width)
            ).rstrip()
            for row in range(max(self.cells) + 1)
        ]

    def first_ink_columns(self) -> list[int]:
        return [min(columns) for _, columns in sorted(self.cells.items()) if columns]


class RenderTests(unittest.TestCase):
    def render(self, width, *, selected=None):
        output = menu.render_menu(
            menu.menu_choices("Linux"),
            "Linux",
            "arm64",
            width,
            focus=0,
            selected=selected or set(),
            color=False,
        )
        screen = RawScreen(width)
        screen.feed("\x1b[H\x1b[2J" + output)
        return output, screen

    def test_raw_output_newlines_reset_to_panel_start(self) -> None:
        output, screen = self.render(80, selected={0})
        self.assertIn("\r\n", output)
        self.assertNotIn("\n", output.replace("\r\n", ""))
        starts = screen.first_ink_columns()
        self.assertGreater(len(starts), 8)
        self.assertEqual({starts[0]}, set(starts), "rows stair-step in raw mode")
        self.assertTrue(all(len(line) <= 80 for line in screen.lines()))
        joined = "\n".join(screen.lines())
        self.assertIn("> [x] Ghostty", joined)
        self.assertIn("selected 1", joined)

    def test_static_layouts_are_bounded_and_keep_context(self) -> None:
        snapshots = {}
        for width in (80, 100):
            output, screen = self.render(width)
            snapshots[width] = "\n".join(screen.lines())
            self.assertTrue(all(len(line) <= width for line in screen.lines()))
            self.assertIn("Dotfiles · LuHer", snapshots[width])
            self.assertIn("Linux / arm64", snapshots[width])
            self.assertIn("> [ ] Ghostty", snapshots[width])
            self.assertIn("selected 0", snapshots[width])
        compact = menu.plain_lines(menu.menu_choices("Linux"), "Linux", "arm64", 40)
        self.assertTrue(all(len(line) <= 40 for line in compact))
        self.assertIn("1) Ghostty", "\n".join(compact))

    def test_go_python_choice_order_has_all_linux_tools(self) -> None:
        self.assertEqual(
            [choice.identifier for choice in menu.menu_choices("Linux")],
            [
                "ghostty",
                "tmux",
                "herdr",
                "starship",
                "zsh",
                "opencode",
                "pi",
                "atuin",
                "zoxide",
                "eza",
                "fnm",
                "zsh-autosuggestions",
                "zsh-syntax-highlighting",
                "neovim",
            ],
        )
        self.assertEqual(len(menu.menu_choices("Darwin")), 15)

    def test_scroll_viewport_keeps_focus_and_selection_count(self) -> None:
        choices = menu.menu_choices("Linux")
        for focus, choice in enumerate(choices):
            output = menu.render_menu(
                choices,
                "Linux",
                "arm64",
                56,
                focus=focus,
                selected={0, len(choices) - 1},
                color=False,
                height=18,
            )
            lines = output.split("\r\n")
            self.assertLessEqual(len(lines), 18)
            self.assertIn(choice.label, output)
            self.assertIn("selected 2", output)
        self.assertEqual((4, 14), menu.visible_range(14, 13, 18))

    def test_no_color_and_dumb_rendering_have_no_sgr_sequences(self) -> None:
        output, _ = self.render(80)
        self.assertNotIn("\x1b[", output)
        plain = "\r\n".join(
            menu.plain_lines(menu.menu_choices("Linux"), "Linux", "arm64", 80)
        )
        self.assertNotIn("\x1b[", plain)
        self.assertFalse(menu.supports_color({"TERM": "dumb"}))
        no_color = menu.render_menu(
            menu.menu_choices("Linux"),
            "Linux",
            "arm64",
            80,
            focus=0,
            selected=set(),
            color=menu.supports_color({"TERM": "xterm-256color", "NO_COLOR": "1"}),
        )
        self.assertNotIn("\x1b[", no_color)


class PtyTests(unittest.TestCase):
    def run_menu(self, keys: bytes, expected: str) -> bytes:
        master, slave = pty.openpty()
        before = termios.tcgetattr(slave)
        environment = os.environ | {
            "TERM": "xterm-256color",
            "COLUMNS": "80",
            "LINES": "24",
        }
        process = subprocess.Popen(
            [sys.executable, "-B", str(MENU_PATH), "--os", "Linux", "--arch", "arm64"],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=slave,
            env=environment,
        )
        try:
            self.assertTrue(select.select([master], [], [], 2)[0], "menu did not draw")
            chunks = [os.read(master, 4096)]
            os.write(master, keys)
            deadline = time.monotonic() + 5
            while process.poll() is None and time.monotonic() < deadline:
                if select.select([master], [], [], 0.1)[0]:
                    try:
                        chunks.append(os.read(master, 4096))
                    except OSError:
                        break
            self.assertIsNotNone(process.poll(), "menu did not exit")
            self.assertEqual(0, process.wait(timeout=1))
            stdout = process.stdout
            if stdout is None:
                self.fail("menu stdout was not captured")
            try:
                self.assertEqual(expected, stdout.read().decode().strip())
            finally:
                stdout.close()
            self.assertEqual(
                before, termios.tcgetattr(slave), "terminal attributes changed"
            )
            return b"".join(chunks)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            os.close(master)
            os.close(slave)

    def test_arrow_space_confirm_and_cancel_restore_the_terminal(self) -> None:
        ui = self.run_menu(b" \x1b[B \r", "ghostty,tmux")
        self.assertIn(b"Ghostty", ui)
        for key in (b"\x1b", b"\x03", b"\x04"):
            self.run_menu(key, "")

    def test_real_arrows_reach_the_last_shell_tool(self) -> None:
        self.run_menu(b"\x1b[B" * 13 + b" \r", "neovim")


if __name__ == "__main__":
    unittest.main(verbosity=2)
