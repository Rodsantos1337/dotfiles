// Package tui is a view over the same step engine: it picks steps, runs them,
// and shows live progress. Sudo prompts and interactive logins hand the
// terminal back with tea.ExecProcess.
package tui

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	tea "github.com/charmbracelet/bubbletea"

	"dotfiles/bootstrap/internal/config"
	"dotfiles/bootstrap/internal/plan"
	"dotfiles/bootstrap/internal/run"
)

// Options is what the CLI hands the TUI.
type Options struct {
	Cfg         config.Config
	Detected    config.Variant
	DotfilesDir string
	Upgrade     bool
	Privatize   bool
}

type stage int

const (
	stageVariant stage = iota
	stageSelect
	stageRunning
	stageDone
)

type row struct {
	isGroup bool
	group   plan.Group
	step    plan.Step
}

type execRequest struct {
	cmd  *exec.Cmd
	done chan error
}

type jobMsg struct {
	ev  *plan.Event
	req *execRequest
}

type tickMsg struct{}

type model struct {
	opts    Options
	variant config.Variant
	stage   stage

	rows       []row
	selected   map[string]bool
	cursor     int
	offset     int
	variantCur int
	width      int
	height     int

	jobs    chan jobMsg
	out     *outputBuffer
	log     io.WriteCloser
	logPath string
	runner  *run.Runner
	work    []plan.Step
	status  map[string]plan.Status
	errs    map[string]error
	current string
	done    int
	total   int
	history []string
	results []plan.Result
	err     error
}

// Run starts the interactive installer.
func Run(opts Options) error {
	m := &model{
		opts:     opts,
		variant:  opts.Detected,
		stage:    stageVariant,
		selected: map[string]bool{},
		status:   map[string]plan.Status{},
		errs:     map[string]error{},
	}
	for i, v := range []config.Variant{config.VariantDesktop, config.VariantLaptop} {
		if v == m.variant {
			m.variantCur = i
		}
	}

	p := tea.NewProgram(m, tea.WithAltScreen())
	final, err := p.Run()
	if err != nil {
		return err
	}
	if fm, ok := final.(*model); ok {
		return fm.err
	}
	return nil
}

func (m *model) Init() tea.Cmd { return nil }

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		return m, nil

	case tickMsg:
		if m.stage == stageRunning {
			return m, tick()
		}
		return m, nil

	case jobMsg:
		return m.handleJob(msg)

	case tea.KeyMsg:
		return m.handleKey(msg)
	}
	return m, nil
}

func (m *model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	key := msg.String()
	switch key {
	case "ctrl+c":
		m.closeLog()
		return m, tea.Quit
	case "q":
		if m.stage != stageRunning {
			m.closeLog()
			return m, tea.Quit
		}
	}

	switch m.stage {
	case stageVariant:
		switch key {
		case "up", "k":
			if m.variantCur > 0 {
				m.variantCur--
				m.variant = variantAt(m.variantCur)
			}
		case "down", "j":
			if m.variantCur < 1 {
				m.variantCur++
				m.variant = variantAt(m.variantCur)
			}
		case "enter", "right", "l", " ":
			m.rebuild()
			m.stage = stageSelect
			m.cursor = 0
			m.offset = 0
		}

	case stageSelect:
		switch key {
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.rows)-1 {
				m.cursor++
			}
		case "pgup":
			m.cursor = max(0, m.cursor-10)
		case "pgdown":
			m.cursor = min(len(m.rows)-1, m.cursor+10)
		case " ":
			m.toggle()
		case "a":
			for _, r := range m.rows {
				if !r.isGroup {
					m.selected[r.step.ID] = true
				}
			}
		case "n":
			for _, r := range m.rows {
				if !r.isGroup {
					m.selected[r.step.ID] = false
				}
			}
		case "enter", "right":
			if len(m.chosen()) == 0 {
				return m, nil
			}
			return m, m.start()
		}

	case stageDone:
		if key == "enter" || key == "q" || key == "esc" {
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m *model) rebuild() {
	cfg := config.BuildConfig(m.variant)
	if m.opts.DotfilesDir != "" {
		cfg.DotfilesDir = m.opts.DotfilesDir
	}
	m.opts.Cfg = cfg

	steps := plan.All(cfg)
	m.rows = buildRows(steps)
	m.selected = map[string]bool{}
	for _, step := range steps {
		m.selected[step.ID] = !step.OptIn
	}
	if m.opts.Upgrade {
		m.selected["dnf-upgrade"] = true
	}
	if m.opts.Privatize {
		m.selected["privatize"] = true
	}
}

func buildRows(steps []plan.Step) []row {
	var rows []row
	seen := map[plan.Group]bool{}
	for _, step := range steps {
		if !seen[step.Group] {
			seen[step.Group] = true
			rows = append(rows, row{isGroup: true, group: step.Group})
		}
		rows = append(rows, row{group: step.Group, step: step})
	}
	return rows
}

func (m *model) toggle() {
	if m.cursor < 0 || m.cursor >= len(m.rows) {
		return
	}
	r := m.rows[m.cursor]
	if r.isGroup {
		on, total := m.groupCount(r.group)
		target := !(on == total)
		for _, step := range m.rows {
			if !step.isGroup && step.group == r.group {
				m.selected[step.step.ID] = target
			}
		}
		return
	}
	m.selected[r.step.ID] = !m.selected[r.step.ID]
}

func (m *model) groupCount(g plan.Group) (on, total int) {
	for _, r := range m.rows {
		if r.isGroup || r.group != g {
			continue
		}
		total++
		if m.selected[r.step.ID] {
			on++
		}
	}
	return
}

func (m *model) chosen() []plan.Step {
	var steps []plan.Step
	for _, r := range m.rows {
		if r.isGroup {
			continue
		}
		if m.selected[r.step.ID] {
			steps = append(steps, r.step)
		}
	}
	return steps
}

func (m *model) start() tea.Cmd {
	m.work = m.chosen()
	m.total = len(m.work)
	m.done = 0
	m.current = ""
	m.history = nil
	m.status = map[string]plan.Status{}
	m.errs = map[string]error{}
	m.stage = stageRunning
	m.out = newOutputBuffer(4000)

	if f, path, err := run.OpenLog(); err == nil {
		m.log = f
		m.logPath = path
	}

	m.runner = &run.Runner{
		Out:         m.out,
		Sudo:        m.sudoPrompt,
		Interactive: m.interactive,
	}
	if m.log != nil {
		m.runner.Log = m.log
	}

	m.jobs = make(chan jobMsg, 256)
	env := &plan.Env{Cfg: m.opts.Cfg, Run: m.runner}
	steps := m.work
	jobs := m.jobs

	go func() {
		plan.Execute(steps, env, func(ev plan.Event) {
			jobs <- jobMsg{ev: &ev}
		})
		close(jobs)
	}()

	return tea.Batch(waitJob(jobs), tick())
}

func (m *model) handleJob(msg jobMsg) (tea.Model, tea.Cmd) {
	if m.stage != stageRunning {
		return m, nil
	}

	if msg.req != nil {
		req := msg.req
		return m, tea.Batch(
			tea.ExecProcess(req.cmd, func(err error) tea.Msg {
				req.done <- err
				return nil
			}),
			waitJob(m.jobs),
		)
	}

	ev := msg.ev
	if ev == nil {
		return m, nil
	}

	switch ev.Kind {
	case plan.EventStart:
		m.current = ev.Step.ID
	case plan.EventSkip:
		m.done = ev.Index
		m.status[ev.Step.ID] = plan.StatusSkipped
		m.history = append(m.history, dim("· "+ev.Step.Title))
	case plan.EventDone:
		m.done = ev.Index
		m.status[ev.Step.ID] = ev.Result.Status
		if ev.Result.Err != nil {
			m.errs[ev.Step.ID] = ev.Result.Err
		}
		switch ev.Result.Status {
		case plan.StatusOK:
			m.history = append(m.history, green("✓ ")+ev.Step.Title)
		case plan.StatusWarned:
			m.history = append(m.history, yellow("! ")+ev.Step.Title+dim(" — "+ev.Result.Err.Error()))
		default:
			m.history = append(m.history, red("✗ ")+ev.Step.Title+dim(" — "+ev.Result.Err.Error()))
		}
	case plan.EventFinished:
		m.results = ev.Results
		m.current = ""
		m.stage = stageDone
		m.closeLog()
		for _, res := range ev.Results {
			if res.Status == plan.StatusFailed {
				m.err = fmt.Errorf("%d step(s) failed — see %s", countFailed(ev.Results), m.logPath)
				break
			}
		}
		return m, nil
	}
	return m, waitJob(m.jobs)
}

func countFailed(results []plan.Result) int {
	n := 0
	for _, res := range results {
		if res.Status == plan.StatusFailed {
			n++
		}
	}
	return n
}

func (m *model) sudoPrompt() error {
	cmd := exec.Command("sudo", "-v")
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return m.requestExec(cmd)
}

func (m *model) interactive(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return m.requestExec(cmd)
}

func (m *model) requestExec(cmd *exec.Cmd) error {
	req := &execRequest{cmd: cmd, done: make(chan error, 1)}
	m.jobs <- jobMsg{req: req}
	return <-req.done
}

func (m *model) closeLog() {
	if m.log != nil {
		_ = m.log.Close()
		m.log = nil
	}
}

// ------------------------------------------------------------------- views

func (m *model) View() string {
	switch m.stage {
	case stageVariant:
		return m.viewVariant()
	case stageSelect:
		return m.viewSelect()
	case stageRunning:
		return m.viewRunning()
	default:
		return m.viewDone()
	}
}

func (m *model) viewVariant() string {
	var b strings.Builder
	b.WriteString("\n  " + bold("dotfiles bootstrap") + dim("  ·  portable Fedora setup") + "\n\n")
	b.WriteString("  " + bold("Which machine is this?") + "\n\n")

	for i, v := range []config.Variant{config.VariantDesktop, config.VariantLaptop} {
		cursor := "  "
		if m.variantCur == i {
			cursor = cyan("› ")
		}
		radio := "( )"
		if m.variant == v {
			radio = cyan("(•)")
		}
		label := bold(string(v))
		if v == m.opts.Detected {
			label += dim("  detected")
		}
		detail := ""
		switch v {
		case config.VariantDesktop:
			detail = dim("   monitors-desktop · flameshot-desktop")
		case config.VariantLaptop:
			detail = dim("   monitors-laptop · thermald/powertop/acpi")
		}
		fmt.Fprintf(&b, "  %s%s %s%s\n", cursor, radio, label, detail)
	}

	b.WriteString("\n  " + dim("↑/↓ choose · enter continue · q quit") + "\n")
	return b.String()
}

func (m *model) viewSelect() string {
	var b strings.Builder
	on, total := 0, 0
	for _, r := range m.rows {
		if !r.isGroup {
			total++
			if m.selected[r.step.ID] {
				on++
			}
		}
	}
	fmt.Fprintf(&b, "\n  %s%s\n\n", bold("dotfiles bootstrap"), dim("  ·  "+string(m.variant)+"  ·  "+fmt.Sprintf("%d/%d steps", on, total)))

	visible := m.height - 9
	if visible < 6 {
		visible = 6
	}
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+visible {
		m.offset = m.cursor - visible + 1
	}
	if m.offset < 0 {
		m.offset = 0
	}
	end := min(len(m.rows), m.offset+visible)

	for i := m.offset; i < end; i++ {
		r := m.rows[i]
		cursor := "  "
		if i == m.cursor {
			cursor = cyan("› ")
		}
		if r.isGroup {
			gon, gtotal := m.groupCount(r.group)
			box := "[ ]"
			switch {
			case gon == gtotal && gtotal > 0:
				box = green("[x]")
			case gon > 0:
				box = yellow("[-]")
			}
			fmt.Fprintf(&b, "%s%s %s  %s\n", cursor, box, bold(plan.GroupTitles[r.group]), dim(fmt.Sprintf("%d/%d", gon, gtotal)))
			continue
		}
		box := dim("[ ]")
		if m.selected[r.step.ID] {
			box = green("[x]")
		}
		label := r.step.Title
		if r.step.NeedsRoot {
			label += dim("  sudo")
		}
		if r.step.Optional {
			label += dim("  optional")
		}
		fmt.Fprintf(&b, "%s  %s %s\n", cursor, box, label)
	}

	b.WriteString("\n  " + dim("↑/↓ move · space toggle · a all · n none · enter run · q quit") + "\n")
	return b.String()
}

func (m *model) viewRunning() string {
	var b strings.Builder
	pct := 0.0
	if m.total > 0 {
		pct = float64(m.done) / float64(m.total)
	}
	fmt.Fprintf(&b, "\n  %s%s\n\n", bold("dotfiles bootstrap"), dim("  ·  "+string(m.variant)))
	fmt.Fprintf(&b, "  %s  %s\n\n", bar(pct, 32), dim(fmt.Sprintf("%d/%d", m.done, m.total)))

	current := ""
	for _, s := range m.work {
		if s.ID == m.current {
			current = s.Title
			break
		}
	}
	if current != "" {
		b.WriteString("  " + cyan("▸ ") + current + "\n")
	} else {
		b.WriteString("  " + dim("working…") + "\n")
	}
	b.WriteString("\n")

	if len(m.history) > 0 {
		start := max(0, len(m.history)-6)
		for _, line := range m.history[start:] {
			b.WriteString("  " + line + "\n")
		}
	}

	b.WriteString("\n  " + dim("output") + "\n")
	tail := m.out.tail(m.outputHeight())
	if len(tail) == 0 {
		b.WriteString("  " + dim("(quiet so far)") + "\n")
	}
	for _, line := range tail {
		b.WriteString("  " + dim(truncate(line, max(20, m.width-6))) + "\n")
	}

	if m.logPath != "" {
		b.WriteString("\n  " + dim("log: "+m.logPath) + "\n")
	}
	return b.String()
}

func (m *model) outputHeight() int {
	h := m.height - 18
	if h < 3 {
		h = 3
	}
	return h
}

func (m *model) viewDone() string {
	ok, skipped, warned, failed := plan.Tally(m.results)
	var b strings.Builder
	b.WriteString("\n  " + bold("dotfiles bootstrap") + dim("  ·  "+string(m.variant)) + "\n\n")

	status := green("complete")
	if failed > 0 {
		status = red("finished with failures")
	}
	fmt.Fprintf(&b, "  %s\n\n", status)
	fmt.Fprintf(&b, "  %s done · %s skipped · %s warned · %s failed\n\n",
		green(fmt.Sprint(ok)), dim(fmt.Sprint(skipped)), yellow(fmt.Sprint(warned)), red(fmt.Sprint(failed)))

	for _, res := range plan.Failures(m.results) {
		icon := yellow("!")
		if res.Status == plan.StatusFailed {
			icon = red("✗")
		}
		fmt.Fprintf(&b, "  %s %s\n      %s\n", icon, res.Step.Title, dim(res.Err.Error()))
	}

	if failed == 0 {
		b.WriteString("\n  " + dim("log out and back in (or $mod+Shift+r in i3) to apply everything") + "\n")
	}
	if m.logPath != "" {
		b.WriteString("\n  " + dim("full log: "+m.logPath) + "\n")
	}
	b.WriteString("\n  " + dim("enter/q close") + "\n")
	return b.String()
}

// ----------------------------------------------------------------- helpers

type outputBuffer struct {
	mu    sync.Mutex
	buf   []byte
	lines []string
	max   int
}

func newOutputBuffer(maxLines int) *outputBuffer {
	return &outputBuffer{max: maxLines}
}

func (o *outputBuffer) Write(p []byte) (int, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.buf = append(o.buf, p...)
	for {
		i := bytes.IndexAny(o.buf, "\n\r")
		if i < 0 {
			break
		}
		o.push(string(o.buf[:i]))
		o.buf = o.buf[i+1:]
	}
	return len(p), nil
}

func (o *outputBuffer) push(line string) {
	line = strings.TrimRight(line, " \t")
	if strings.TrimSpace(line) == "" {
		return
	}
	o.lines = append(o.lines, line)
	if len(o.lines) > o.max {
		o.lines = o.lines[len(o.lines)-o.max:]
	}
}

func (o *outputBuffer) tail(n int) []string {
	if o == nil {
		return nil
	}
	o.mu.Lock()
	defer o.mu.Unlock()
	if n > len(o.lines) {
		n = len(o.lines)
	}
	out := make([]string, n)
	copy(out, o.lines[len(o.lines)-n:])
	return out
}

func waitJob(ch chan jobMsg) tea.Cmd {
	return func() tea.Msg {
		msg, ok := <-ch
		if !ok {
			return nil
		}
		return msg
	}
}

func tick() tea.Cmd {
	return tea.Tick(120*time.Millisecond, func(time.Time) tea.Msg { return tickMsg{} })
}

func variantAt(i int) config.Variant {
	if i == 1 {
		return config.VariantLaptop
	}
	return config.VariantDesktop
}

func bar(pct float64, width int) string {
	if pct < 0 {
		pct = 0
	}
	if pct > 1 {
		pct = 1
	}
	filled := int(float64(width) * pct)
	return green(strings.Repeat("█", filled)) + dim(strings.Repeat("░", width-filled))
}

func truncate(s string, width int) string {
	runes := []rune(s)
	if len(runes) <= width {
		return s
	}
	if width <= 1 {
		return string(runes[:width])
	}
	return string(runes[:width-1]) + "…"
}

func bold(s string) string   { return "\033[1m" + s + "\033[0m" }
func dim(s string) string    { return "\033[2m" + s + "\033[0m" }
func green(s string) string  { return "\033[32m" + s + "\033[0m" }
func red(s string) string    { return "\033[31m" + s + "\033[0m" }
func yellow(s string) string { return "\033[33m" + s + "\033[0m" }
func cyan(s string) string   { return "\033[36m" + s + "\033[0m" }

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
