package main

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

func TestModelStartsEmptyAndSelectsWithKeyboard(t *testing.T) {
	m := newModel("Darwin", "arm64", true)
	if got, want := len(m.choices), 15; got != want {
		t.Fatalf("choices = %d, want %d", got, want)
	}
	if got := m.csv(); got != "" {
		t.Fatalf("initial CSV = %q, want empty", got)
	}

	m = updateModel(t, m, tea.KeyMsg{Type: tea.KeyDown})
	m = updateModel(t, m, tea.KeyMsg{Type: tea.KeySpace})
	if got, want := m.csv(), "tmux"; got != want {
		t.Fatalf("CSV after down/space = %q, want %q", got, want)
	}
	m = updateModel(t, m, tea.KeyMsg{Type: tea.KeyEnter})
	if !m.done || m.cancelled {
		t.Fatalf("enter state = done:%t cancelled:%t", m.done, m.cancelled)
	}
}

func TestChoiceOrderMatchesTheBackendAllowlist(t *testing.T) {
	wantLinux := []string{
		"ghostty", "tmux", "herdr", "starship", "zsh", "opencode", "pi",
		"atuin", "zoxide", "eza", "fnm", "zsh-autosuggestions",
		"zsh-syntax-highlighting", "neovim",
	}
	linux := newModel("Linux", "x86_64", false)
	if got := linux.selectedIDs(); len(got) != 0 {
		t.Fatalf("initial selected IDs = %v, want none", got)
	}
	for index, want := range wantLinux {
		if got := linux.choices[index].id; got != want {
			t.Fatalf("Linux choice %d = %q, want %q", index, got, want)
		}
	}
	mac := newModel("Darwin", "arm64", false)
	if got, want := mac.choices[len(mac.choices)-1].id, "aerospace"; got != want {
		t.Fatalf("final macOS choice = %q, want %q", got, want)
	}
}

func TestLineFeedConfirmsASelection(t *testing.T) {
	m := newModel("Linux", "x86_64", false)
	m = updateModel(t, m, tea.KeyMsg{Type: tea.KeySpace})
	m = updateModel(t, m, tea.KeyMsg{Type: tea.KeyCtrlJ})
	if !m.done || m.cancelled || m.csv() != "ghostty" {
		t.Fatalf("line feed did not confirm safely: done:%t cancelled:%t csv:%q", m.done, m.cancelled, m.csv())
	}
}

func TestCancelAndEOFCannotProduceASelection(t *testing.T) {
	for _, key := range []tea.KeyType{tea.KeyEsc, tea.KeyCtrlC, tea.KeyCtrlD} {
		m := newModel("Linux", "x86_64", true)
		m = updateModel(t, m, tea.KeyMsg{Type: tea.KeySpace})
		m = updateModel(t, m, tea.KeyMsg{Type: key})
		if !m.done || !m.cancelled || m.csv() != "" {
			t.Fatalf("key %v left unsafe state: done:%t cancelled:%t csv:%q", key, m.done, m.cancelled, m.csv())
		}
	}
}

func TestResponsiveViewsUseActualANSIWidth(t *testing.T) {
	for _, tc := range []struct {
		name          string
		width, height int
		color         bool
	}{
		{name: "tiny plain", width: 40, height: 7, color: false},
		{name: "minimum visual", width: 56, height: 10, color: false},
		{name: "compact", width: 80, height: 14, color: true},
		{name: "spacious", width: 100, height: 30, color: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			m := newModel("Darwin", "arm64", tc.color)
			m = updateModel(t, m, tea.WindowSizeMsg{Width: tc.width, Height: tc.height})
			view := m.View()
			if view == "" {
				t.Fatal("view is empty")
			}
			for _, line := range strings.Split(view, "\n") {
				if got := lipgloss.Width(line); got > tc.width {
					t.Fatalf("line width = %d, exceeds terminal width %d: %q", got, tc.width, line)
				}
			}
			if !tc.color && strings.Contains(view, "\x1b[") {
				t.Fatalf("plain fallback contains ANSI: %q", view)
			}
			if tc.width >= 80 && !strings.Contains(view, "Dotfiles · LuHer") {
				t.Fatalf("view lacks title: %q", view)
			}
			if tc.width >= 56 && tc.height >= 10 && len(strings.Split(view, "\n")) > tc.height {
				t.Fatalf("visual view has %d rows, exceeds terminal height %d", len(strings.Split(view, "\n")), tc.height)
			}
		})
	}
}

func TestBannerUsesSoftBlueForegroundWithoutBackgroundSlabs(t *testing.T) {
	m := newModel("Darwin", "arm64", true)
	foreground, ok := m.styles.banner.GetForeground().(lipgloss.AdaptiveColor)
	if !ok {
		t.Fatalf("banner foreground = %T, want adaptive color", m.styles.banner.GetForeground())
	}
	if foreground.Light != "#1D4ED8" || foreground.Dark != "#89B4FA" {
		t.Fatalf("unexpected banner blue: %#v", foreground)
	}
	for name, style := range map[string]lipgloss.Style{"banner": m.styles.banner, "focus": m.styles.focus, "row": m.styles.row} {
		if _, noColor := style.GetBackground().(lipgloss.NoColor); !noColor {
			t.Fatalf("%s background = %#v, want no background slab", name, style.GetBackground())
		}
	}
	if strings.Contains(m.View(), "\x1b[48;") {
		t.Fatalf("view contains a background ANSI sequence: %q", m.View())
	}
}

func TestPanelRowsAlignDescriptionsAndBorders(t *testing.T) {
	m := newModel("Darwin", "arm64", false)
	m = updateModel(t, m, tea.WindowSizeMsg{Width: 100, Height: 30})
	columns := make(map[int]bool)
	for index, option := range m.choices {
		line := m.choiceLine(index, option, 92)
		start := strings.Index(line, option.description)
		if start < 0 {
			t.Fatalf("description missing from row %q: %q", option.label, line)
		}
		columns[lipgloss.Width(line[:start])] = true
	}
	if len(columns) != 1 {
		t.Fatalf("description columns = %v, want one aligned column", columns)
	}

	view := m.View()
	lines := strings.Split(view, "\n")
	width := lipgloss.Width(lines[0])
	for _, line := range lines {
		if got := lipgloss.Width(line); got != width {
			t.Fatalf("panel line width = %d, want %d: %q", got, width, line)
		}
	}
}

func TestCompactPanelKeepsEveryChoiceReachable(t *testing.T) {
	m := newModel("Darwin", "arm64", false)
	m = updateModel(t, m, tea.WindowSizeMsg{Width: 56, Height: 18})
	for index, option := range m.choices {
		if view := m.View(); !strings.Contains(view, option.label) {
			t.Fatalf("choice %d (%s) is not visible in compact panel:\n%s", index, option.label, view)
		}
		m = updateModel(t, m, tea.KeyMsg{Type: tea.KeyDown})
	}
}

func TestNavigationReachesEveryToolAndReturnsItsExactIDAtAnyViewport(t *testing.T) {
	for _, viewport := range []struct{ width, height int }{{80, 24}, {56, 18}, {40, 12}} {
		m := newModel("Linux", "x86_64", false)
		m = updateModel(t, m, tea.WindowSizeMsg{Width: viewport.width, Height: viewport.height})
		for range m.choices {
			m = updateModel(t, m, tea.KeyMsg{Type: tea.KeyDown})
		}
		if got := m.cursor; got != 0 {
			t.Fatalf("%dx%d: cursor after full cycle = %d, want 0", viewport.width, viewport.height, got)
		}
		for range m.choices[:len(m.choices)-1] {
			m = updateModel(t, m, tea.KeyMsg{Type: tea.KeyDown})
		}
		m = updateModel(t, m, tea.KeyMsg{Type: tea.KeySpace})
		if got, want := m.csv(), "neovim"; got != want {
			t.Fatalf("%dx%d: final tool selection = %q, want %q", viewport.width, viewport.height, got, want)
		}
		if got, want := len(m.selectedIDs()), 1; got != want {
			t.Fatalf("%dx%d: selected count = %d, want %d", viewport.width, viewport.height, got, want)
		}
	}
}

var ansiSequence = regexp.MustCompile(`\x1b\[[0-?]*[ -/]*[@-~]`)

func TestScrollingAndResizePreserveSelections(t *testing.T) {
	m := newModel("Linux", "x86_64", false)
	m = updateModel(t, m, tea.WindowSizeMsg{Width: 56, Height: 18})
	m = updateModel(t, m, tea.KeyMsg{Type: tea.KeySpace})
	for range m.choices[:len(m.choices)-1] {
		m = updateModel(t, m, tea.KeyMsg{Type: tea.KeyDown})
	}
	if view := m.View(); !strings.Contains(view, "Neovim") {
		t.Fatalf("focused final choice is outside the scroll viewport:\n%s", view)
	}
	m = updateModel(t, m, tea.KeyMsg{Type: tea.KeySpace})
	if got, want := m.csv(), "ghostty,neovim"; got != want {
		t.Fatalf("scrolling changed selected IDs: got %q, want %q", got, want)
	}
	m = updateModel(t, m, tea.WindowSizeMsg{Width: 80, Height: 24})
	if got, want := len(m.selectedIDs()), 2; got != want {
		t.Fatalf("resize changed selected count: got %d, want %d", got, want)
	}
	if view := m.View(); !strings.Contains(view, "2 seleccionados") {
		t.Fatalf("resize lost selected status:\n%s", view)
	}
}

func TestRenderGoldens(t *testing.T) {
	for _, tc := range []struct {
		name          string
		width, height int
	}{
		{name: "100x30", width: 100, height: 30},
		{name: "80x24", width: 80, height: 24},
		{name: "150x20", width: 150, height: 20},
		{name: "56x18", width: 56, height: 18},
		{name: "40x12", width: 40, height: 12},
	} {
		t.Run(tc.name, func(t *testing.T) {
			m := newModel("Darwin", "arm64", true)
			m.cursor = 1
			m.selected[1] = true
			m = updateModel(t, m, tea.WindowSizeMsg{Width: tc.width, Height: tc.height})
			raw := m.View()
			if strings.Contains(raw, "\x1b[48;") {
				t.Fatalf("render contains a background ANSI sequence: %q", raw)
			}
			got := ansiSequence.ReplaceAllString(raw, "") + "\n"
			path := filepath.Join("testdata", tc.name+".golden")
			if os.Getenv("UPDATE_GOLDEN") == "1" {
				if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(path, []byte(got), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			want, err := os.ReadFile(path)
			if err != nil {
				t.Fatalf("read %s: %v", path, err)
			}
			if got != string(want) {
				t.Fatalf("render mismatch for %s (-want +got)\nwant:\n%s\ngot:\n%s", tc.name, want, got)
			}
		})
	}
}

func TestZeroSizedResizeKeepsTheUsefulViewport(t *testing.T) {
	m := newModel("Darwin", "arm64", false)
	m = updateModel(t, m, tea.WindowSizeMsg{})
	if m.width != 80 || m.height != 24 {
		t.Fatalf("zero resize changed the default viewport to %dx%d", m.width, m.height)
	}
}

func TestLinuxMenuOmitsMacOnlyChoice(t *testing.T) {
	m := newModel("Linux", "x86_64", false)
	if strings.Contains(m.View(), "AeroSpace") {
		t.Fatal("Linux menu includes AeroSpace")
	}
}

func updateModel(t *testing.T, m model, msg tea.Msg) model {
	t.Helper()
	updated, _ := m.Update(msg)
	result, ok := updated.(model)
	if !ok {
		t.Fatalf("Update returned %T, want model", updated)
	}
	return result
}
