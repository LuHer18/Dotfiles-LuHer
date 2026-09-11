package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"runtime"
	"strconv"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/term"
	"golang.org/x/sys/unix"
)

type choice struct {
	id          string
	label       string
	description string
}

type styles struct {
	banner   lipgloss.Style
	border   lipgloss.Style
	chevron  lipgloss.Style
	focus    lipgloss.Style
	icon     lipgloss.Style
	muted    lipgloss.Style
	row      lipgloss.Style
	selected lipgloss.Style
}

const (
	// These Darwin-only ioctl values stay numeric so the Linux build does not
	// reference Darwin-specific unix constants.
	darwinTIOCGETA  uint = 0x40487413
	darwinTIOCFLUSH uint = 0x80047410
	darwinTCIFLUSH       = 1
	darwinPENDIN         = 0x20000000
)

type terminalSnapshot struct {
	fd         uintptr
	state      *term.State
	hadPending bool
}

func captureTerminal(input io.Reader) (terminalSnapshot, error) {
	file, ok := input.(interface{ Fd() uintptr })
	if !ok || !term.IsTerminal(file.Fd()) {
		return terminalSnapshot{}, nil
	}
	state, err := term.GetState(file.Fd())
	if err != nil {
		return terminalSnapshot{}, err
	}
	snapshot := terminalSnapshot{fd: file.Fd(), state: state}
	if runtime.GOOS == "darwin" {
		current, err := unix.IoctlGetTermios(int(snapshot.fd), darwinTIOCGETA)
		if err != nil {
			return terminalSnapshot{}, err
		}
		snapshot.hadPending = current.Lflag&darwinPENDIN != 0
	}
	return snapshot, nil
}

func (s terminalSnapshot) restore() error {
	if s.state == nil {
		return nil
	}

	var flushErr error
	if runtime.GOOS == "darwin" && !s.hadPending {
		current, err := unix.IoctlGetTermios(int(s.fd), darwinTIOCGETA)
		if err != nil {
			flushErr = err
		} else if current.Lflag&darwinPENDIN != 0 {
			// Bubble Tea restores raw mode, but Darwin can retain PENDIN while
			// queued keystrokes are replayed. Flush only that newly-pending input.
			flushErr = unix.IoctlSetPointerInt(int(s.fd), darwinTIOCFLUSH, darwinTCIFLUSH)
		}
	}
	restoreErr := term.Restore(s.fd, s.state)
	if flushErr != nil {
		return flushErr
	}
	return restoreErr
}

type model struct {
	choices   []choice
	osName    string
	arch      string
	cursor    int
	offset    int
	selected  map[int]bool
	width     int
	height    int
	color     bool
	done      bool
	cancelled bool
	styles    styles
}

func choicesForOS(osName string) []choice {
	choices := []choice{
		{id: "ghostty", label: "Ghostty", description: "Terminal moderno y configurable"},
		{id: "tmux", label: "tmux", description: "Multiplexor de terminal"},
		{id: "herdr", label: "Herdr", description: "Multiplexor para sesiones con agentes de IA"},
		{id: "starship", label: "Starship", description: "Prompt rápido y personalizable"},
		{id: "zsh", label: "Zsh", description: "Shell interactiva"},
		{id: "opencode", label: "OpenCode", description: "Agente de programación de terminal"},
		{id: "pi", label: "Pi", description: "Pi (opcional; +7 extensiones)"},
		{id: "atuin", label: "Atuin", description: "Historial de shell sincronizable"},
		{id: "zoxide", label: "Zoxide", description: "Navegación rápida entre directorios"},
		{id: "eza", label: "eza", description: "Listado moderno de archivos"},
		{id: "fnm", label: "fnm", description: "Gestor rápido de versiones de Node.js"},
		{id: "zsh-autosuggestions", label: "Autosugerencias Zsh", description: "Sugerencias mientras escribes en Zsh"},
		{id: "zsh-syntax-highlighting", label: "Resaltado Zsh", description: "Colores de sintaxis para Zsh"},
		{id: "neovim", label: "Neovim", description: "Editor extensible (ejecutable: nvim)"},
	}
	if osName == "Darwin" {
		choices = append(choices, choice{id: "aerospace", label: "AeroSpace", description: "Gestor de ventanas para macOS"})
	}
	return choices
}

func displayOS(osName string) string {
	if osName == "Darwin" {
		return "macOS"
	}
	return osName
}

func newStyles(renderer *lipgloss.Renderer, color bool) styles {
	if !color {
		return styles{}
	}

	bannerBlue := lipgloss.AdaptiveColor{Light: "#1D4ED8", Dark: "#89B4FA"}
	softBlue := lipgloss.AdaptiveColor{Light: "#2563EB", Dark: "#B4D0FB"}
	mutedBlue := lipgloss.AdaptiveColor{Light: "#64748B", Dark: "#94A3B8"}
	return styles{
		banner:   renderer.NewStyle().Foreground(bannerBlue).Bold(true),
		border:   renderer.NewStyle().Foreground(softBlue),
		chevron:  renderer.NewStyle().Foreground(bannerBlue).Bold(true),
		focus:    renderer.NewStyle().Foreground(bannerBlue).Bold(true).Underline(true),
		icon:     renderer.NewStyle().Foreground(softBlue).Bold(true),
		muted:    renderer.NewStyle().Foreground(mutedBlue),
		row:      renderer.NewStyle(),
		selected: renderer.NewStyle().Foreground(softBlue).Bold(true),
	}
}

func newModel(osName, arch string, color bool) model {
	return model{
		choices:  choicesForOS(osName),
		osName:   osName,
		arch:     arch,
		selected: make(map[int]bool),
		width:    80,
		height:   24,
		color:    color,
		styles:   newStyles(lipgloss.NewRenderer(os.Stderr), color),
	}
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		// Pseudo-terminals can report a transient 0×0 size before their owner
		// configures the window. Keep the useful default until a real resize arrives.
		if msg.Width > 0 {
			m.width = msg.Width
		}
		if msg.Height > 0 {
			m.height = msg.Height
		}
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "ctrl+d", "esc":
			m.done = true
			m.cancelled = true
			return m, tea.Quit
		case "up":
			m.cursor = (m.cursor - 1 + len(m.choices)) % len(m.choices)
		case "down":
			m.cursor = (m.cursor + 1) % len(m.choices)
		case " ":
			m.selected[m.cursor] = !m.selected[m.cursor]
		case "enter", "ctrl+j":
			m.done = true
			return m, tea.Quit
		}
	}
	m.ensureCursorVisible()
	return m, nil
}

func (m model) csv() string {
	if m.cancelled {
		return ""
	}
	selected := make([]string, 0, len(m.selected))
	for index, option := range m.choices {
		if m.selected[index] {
			selected = append(selected, option.id)
		}
	}
	return strings.Join(selected, ",")
}

func (m model) View() string {
	// The panel has a border, compact terminal mark, dividers, and two footer
	// lines. Below that height, use the textual view so every option remains
	// visible instead of rendering a cropped menu.
	if m.width < 56 || m.height < 10 {
		return m.plainView()
	}
	return m.panelView()
}

func (m model) plainView() string {
	lines := []string{fit(fmt.Sprintf("Dotfiles · LuHer — %s / %s", displayOS(m.osName), m.arch), m.width)}
	for index, option := range m.choices {
		marker := " "
		if m.selected[index] {
			marker = "x"
		}
		cursor := " "
		if index == m.cursor {
			cursor = ">"
		}
		lines = append(lines, fit(fmt.Sprintf("%s [%s] %d) %s — %s", cursor, marker, index+1, option.label, option.description), m.width))
	}
	footer := "↑↓ mover · Espacio marcar · Enter confirmar · Esc cancelar"
	if m.done {
		footer = completionMessage(m.cancelled)
	}
	lines = append(lines, fit(footer, m.width))
	return strings.Join(lines, "\n")
}

func (m model) panelView() string {
	panelWidth := min(m.width-2, 96)
	contentWidth := panelWidth - 4
	spacious := m.isSpacious()
	lines := []string{m.panelEdge("╭", "╮", panelWidth)}

	for _, header := range m.headerLines(contentWidth, spacious) {
		lines = append(lines, m.panelLine(header, contentWidth))
	}
	lines = append(lines, m.panelLine(m.divider("── componentes ", contentWidth), contentWidth))
	start, end := m.visibleRange()
	for index := start; index < end; index++ {
		lines = append(lines, m.panelLine(m.choiceLine(index, m.choices[index], contentWidth), contentWidth))
	}
	lines = append(lines, m.panelLine(m.divider("", contentWidth), contentWidth))
	if m.done {
		lines = append(lines, m.panelLine(m.styles.muted.Render(fit(completionMessage(m.cancelled), contentWidth)), contentWidth))
	} else {
		status := fmt.Sprintf("%d seleccionados", len(m.selectedIDs()))
		if end-start < len(m.choices) {
			status += fmt.Sprintf(" · mostrando %d–%d de %d", start+1, end, len(m.choices))
		}
		lines = append(lines,
			m.panelLine(m.styles.muted.Render(fit(status, contentWidth)), contentWidth),
			m.panelLine(m.styles.muted.Render(fit("↑↓ mover · Espacio marcar · Enter confirmar · Esc cancelar", contentWidth)), contentWidth),
		)
	}
	lines = append(lines, m.panelEdge("╰", "╯", panelWidth))
	return indent(strings.Join(lines, "\n"), max(0, (m.width-panelWidth)/2))
}

func (m model) headerLines(_ int, spacious bool) []string {
	if !spacious {
		return []string{
			m.styles.icon.Render("╭─────╮") + "  " + m.styles.banner.Render("Dotfiles · LuHer"),
			m.styles.icon.Render("│ >_  │") + "  " + m.styles.muted.Render(fmt.Sprintf("%s / %s", displayOS(m.osName), m.arch)),
			m.styles.icon.Render("╰─────╯") + "  " + m.styles.muted.Render("selector de componentes"),
		}
	}

	terminal := strings.Join([]string{
		"╭─────╮",
		"│ >_  │",
		"│     │",
		"│ $ _ │",
		"╰─────╯",
	}, "\n")
	header := lipgloss.JoinHorizontal(lipgloss.Top, m.styles.icon.Render(terminal), "  ", m.styles.banner.Render(dotfilesWordmark()))
	return append(strings.Split(header, "\n"), m.styles.muted.Render(fmt.Sprintf("Dotfiles · LuHer  ·  %s / %s", displayOS(m.osName), m.arch)))
}

func dotfilesWordmark() string {
	glyphs := map[rune][5]string{
		'D': {"████ ", "█   █", "█   █", "█   █", "████ "},
		'O': {" ███ ", "█   █", "█   █", "█   █", " ███ "},
		'T': {"█████", "  █  ", "  █  ", "  █  ", "  █  "},
		'F': {"█████", "█    ", "████ ", "█    ", "█    "},
		'I': {"█████", "  █  ", "  █  ", "  █  ", "█████"},
		'L': {"█    ", "█    ", "█    ", "█    ", "█████"},
		'E': {"█████", "█    ", "████ ", "█    ", "█████"},
		'S': {" ████", "█    ", " ███ ", "    █", "████ "},
	}
	lines := make([]string, 5)
	for _, letter := range "DOTFILES" {
		for row, line := range glyphs[letter] {
			if lines[row] != "" {
				lines[row] += " "
			}
			lines[row] += line
		}
	}
	return strings.Join(lines, "\n")
}

func (m model) choiceLine(index int, option choice, width int) string {
	const labelWidth = 22

	marker := "[ ]"
	if m.selected[index] {
		marker = "[✓]"
	}
	pointer := " "
	if index == m.cursor {
		pointer = m.styles.chevron.Render("›")
	}
	label := pad(fit(option.label, labelWidth), labelWidth)
	labelStyle := m.styles.row
	if m.selected[index] {
		labelStyle = m.styles.selected
	}
	if index == m.cursor {
		labelStyle = m.styles.focus
	}
	prefix := pointer + " " + marker + " "
	descriptionWidth := max(0, width-lipgloss.Width(prefix)-labelWidth-2)
	description := fit(option.description, descriptionWidth)
	return prefix + labelStyle.Render(label) + "  " + m.styles.muted.Render(description)
}

func (m model) panelChromeHeight() int {
	footerLines := 2
	if m.done {
		footerLines = 1
	}
	return 2 + len(m.headerLines(0, m.isSpacious())) + 2 + footerLines
}

func (m model) rowCapacity() int {
	return max(1, m.height-m.panelChromeHeight())
}

func (m model) isSpacious() bool {
	return m.width >= 80 && m.height >= len(m.choices)+14
}

func (m *model) ensureCursorVisible() {
	capacity := m.rowCapacity()
	maximumOffset := max(0, len(m.choices)-capacity)
	m.offset = min(max(0, m.offset), maximumOffset)
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+capacity {
		m.offset = m.cursor - capacity + 1
	}
}

func (m model) visibleRange() (int, int) {
	capacity := m.rowCapacity()
	maximumOffset := max(0, len(m.choices)-capacity)
	start := min(max(0, m.offset), maximumOffset)
	if m.cursor < start {
		start = m.cursor
	}
	if m.cursor >= start+capacity {
		start = m.cursor - capacity + 1
	}
	return start, min(len(m.choices), start+capacity)
}

func (m model) divider(label string, width int) string {
	return m.styles.muted.Render(label + strings.Repeat("─", max(0, width-lipgloss.Width(label))))
}

func (m model) panelEdge(left, right string, width int) string {
	return m.styles.border.Render(left + strings.Repeat("─", max(0, width-2)) + right)
}

func (m model) panelLine(content string, width int) string {
	return m.styles.border.Render("│") + " " + pad(content, width) + " " + m.styles.border.Render("│")
}

func (m model) selectedIDs() []string {
	ids := make([]string, 0, len(m.selected))
	for index, option := range m.choices {
		if m.selected[index] {
			ids = append(ids, option.id)
		}
	}
	return ids
}

func completionMessage(cancelled bool) string {
	if cancelled {
		return "Cancelado; no se realizaron cambios."
	}
	return "Selección confirmada; el plan se muestra a continuación."
}

func pad(value string, width int) string {
	return value + strings.Repeat(" ", max(0, width-lipgloss.Width(value)))
}

func fit(value string, width int) string {
	if width <= 0 {
		return ""
	}
	if lipgloss.Width(value) <= width {
		return value
	}
	if width == 1 {
		return "…"
	}
	var builder strings.Builder
	for _, runeValue := range value {
		candidate := builder.String() + string(runeValue)
		if lipgloss.Width(candidate)+lipgloss.Width("…") > width {
			break
		}
		builder.WriteRune(runeValue)
	}
	return builder.String() + "…"
}

func indent(value string, width int) string {
	if width <= 0 {
		return value
	}
	prefix := strings.Repeat(" ", width)
	return prefix + strings.ReplaceAll(value, "\n", "\n"+prefix)
}

func supportsColor(environment []string) bool {
	for _, entry := range environment {
		if entry == "NO_COLOR" || strings.HasPrefix(entry, "NO_COLOR=") {
			return false
		}
	}
	term := os.Getenv("TERM")
	return term != "" && term != "dumb"
}

func isPlainTerminal() bool {
	term := os.Getenv("TERM")
	if term == "" || term == "dumb" {
		return true
	}
	columns, haveColumns := environmentInt("COLUMNS")
	lines, haveLines := environmentInt("LINES")
	return haveColumns && haveLines && (columns < 56 || lines < 12)
}

func environmentInt(name string) (int, bool) {
	value, err := strconv.Atoi(os.Getenv(name))
	return value, err == nil && value > 0
}

func plainSelection(osName, arch string, input io.Reader, output io.Writer) string {
	choices := choicesForOS(osName)
	width, ok := environmentInt("COLUMNS")
	if !ok {
		width = 80
	}
	for _, line := range newModel(osName, arch, false).plainViewLines(width) {
		fmt.Fprintln(output, line)
	}
	fmt.Fprintln(output, "Números separados por comas; Enter cancela:")

	answer, err := bufio.NewReader(input).ReadString('\n')
	if err != nil {
		return ""
	}
	answer = strings.TrimSpace(answer)
	if answer == "" {
		return ""
	}

	selected := make([]string, 0, len(choices))
	seen := make(map[string]bool)
	for _, token := range strings.Split(answer, ",") {
		index, parseErr := strconv.Atoi(strings.TrimSpace(token))
		if parseErr != nil || index < 1 || index > len(choices) {
			fmt.Fprintln(output, "Selección inválida; no se realizaron cambios.")
			return ""
		}
		id := choices[index-1].id
		if !seen[id] {
			seen[id] = true
			selected = append(selected, id)
		}
	}
	return strings.Join(selected, ",")
}

func (m model) plainViewLines(width int) []string {
	lines := []string{fit(fmt.Sprintf("Dotfiles · LuHer — %s / %s", displayOS(m.osName), m.arch), width)}
	for index, option := range m.choices {
		lines = append(lines, fit(fmt.Sprintf("%d) %s — %s", index+1, option.label, option.description), width))
	}
	return lines
}

func parseArguments(arguments []string, stderr io.Writer) (string, string, error) {
	flags := flag.NewFlagSet("dotfiles-tui", flag.ContinueOnError)
	flags.SetOutput(stderr)
	osName := flags.String("os", "", "target operating system")
	arch := flags.String("arch", "", "target architecture")
	if err := flags.Parse(arguments); err != nil {
		return "", "", err
	}
	if *osName == "" || *arch == "" {
		return "", "", errors.New("--os and --arch are required")
	}
	return *osName, *arch, nil
}

func run(arguments []string, stdin io.Reader, stdout, stderr io.Writer) int {
	osName, arch, err := parseArguments(arguments, stderr)
	if err != nil {
		fmt.Fprintln(stderr, "dotfiles-tui:", err)
		return 2
	}
	if isPlainTerminal() {
		fmt.Fprintln(stdout, plainSelection(osName, arch, stdin, stderr))
		return 0
	}

	snapshot, err := captureTerminal(stdin)
	if err != nil {
		fmt.Fprintln(stderr, "dotfiles-tui: capture terminal:", err)
		return 1
	}
	program := tea.NewProgram(newModel(osName, arch, supportsColor(os.Environ())), tea.WithInput(stdin), tea.WithOutput(stderr))
	final, runErr := program.Run()
	if err := snapshot.restore(); err != nil {
		fmt.Fprintln(stderr, "dotfiles-tui: restore terminal:", err)
		return 1
	}
	if runErr != nil {
		fmt.Fprintln(stderr, "dotfiles-tui:", runErr)
		return 1
	}
	result, ok := final.(model)
	if !ok {
		fmt.Fprintln(stderr, "dotfiles-tui: unexpected final model")
		return 1
	}
	fmt.Fprintln(stdout, result.csv())
	return 0
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}
