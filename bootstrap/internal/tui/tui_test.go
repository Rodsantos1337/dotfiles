package tui

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"

	"dotfiles/bootstrap/internal/config"
	"dotfiles/bootstrap/internal/plan"
)

func newTestModel() *model {
	cfg := config.BuildConfig(config.VariantDesktop)
	cfg.DotfilesDir = "/tmp/does-not-matter"
	return &model{
		opts:     Options{Cfg: cfg, Detected: config.VariantDesktop},
		variant:  config.VariantDesktop,
		stage:    stageVariant,
		selected: map[string]bool{},
		status:   map[string]plan.Status{},
		errs:     map[string]error{},
	}
}

func key(t *testing.T, m *model, msg tea.KeyMsg) *model {
	t.Helper()
	updated, _ := m.Update(msg)
	next, ok := updated.(*model)
	if !ok {
		t.Fatalf("Update returned %T, want *model", updated)
	}
	return next
}

func runes(t *testing.T, m *model, s string) *model {
	t.Helper()
	return key(t, m, tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(s)})
}

func enter(t *testing.T, m *model) *model {
	t.Helper()
	return key(t, m, tea.KeyMsg{Type: tea.KeyEnter})
}

func TestVariantScreenShowsBothChoices(t *testing.T) {
	m := newTestModel()
	m.width, m.height = 100, 40
	view := m.View()
	for _, want := range []string{"desktop", "laptop", "Which machine is this"} {
		if !strings.Contains(view, want) {
			t.Errorf("variant screen missing %q", want)
		}
	}
}

func TestEnterBuildsSelectableSteps(t *testing.T) {
	m := newTestModel()
	m.width, m.height = 100, 40
	m = enter(t, m)

	if m.stage != stageSelect {
		t.Fatalf("stage = %v, want stageSelect", m.stage)
	}
	if len(m.rows) == 0 {
		t.Fatal("no rows built")
	}
	view := m.View()
	for _, want := range []string{"system repositories", "dotfiles", "symlink"} {
		if !strings.Contains(view, want) {
			t.Errorf("select screen missing %q", want)
		}
	}
}

func TestOptInStepsAreOffByDefault(t *testing.T) {
	m := newTestModel()
	m.width, m.height = 100, 40
	m = enter(t, m)

	if m.selected["dnf-upgrade"] {
		t.Error("dnf-upgrade should be opt-in")
	}
	if m.selected["privatize"] {
		t.Error("privatize should be opt-in")
	}
	if !m.selected["dnf-pkgs"] || !m.selected["links"] {
		t.Error("core steps should be selected by default")
	}
}

func TestGroupToggleAndSelectAll(t *testing.T) {
	m := newTestModel()
	m.width, m.height = 100, 40
	m = enter(t, m)

	all := len(m.chosen())
	if all == 0 {
		t.Fatal("nothing selected by default")
	}

	// "n" clears everything.
	m = runes(t, m, "n")
	if got := len(m.chosen()); got != 0 {
		t.Fatalf("after n: %d steps selected, want 0", got)
	}

	// "a" selects everything.
	m = runes(t, m, "a")
	if got := len(m.chosen()); got == 0 {
		t.Fatal("after a: nothing selected")
	}

	// Space on the first row (a group header) turns the whole group off.
	m.cursor = 0
	if !m.rows[0].isGroup {
		t.Fatal("first row should be a group header")
	}
	group := m.rows[0].group
	m = runes(t, m, " ")
	for _, r := range m.rows {
		if !r.isGroup && r.group == group && m.selected[r.step.ID] {
			t.Fatalf("step %s still selected after toggling group %s", r.step.ID, group)
		}
	}

	// Toggling again turns it back on.
	m = runes(t, m, " ")
	count := 0
	for _, r := range m.rows {
		if !r.isGroup && r.group == group && m.selected[r.step.ID] {
			count++
		}
	}
	if count == 0 {
		t.Fatalf("group %s did not come back on", group)
	}
}

func TestCursorStaysInBounds(t *testing.T) {
	m := newTestModel()
	m.width, m.height = 100, 20
	m = enter(t, m)

	for i := 0; i < len(m.rows)*2; i++ {
		m = key(t, m, tea.KeyMsg{Type: tea.KeyDown})
	}
	if m.cursor != len(m.rows)-1 {
		t.Fatalf("cursor = %d, want %d", m.cursor, len(m.rows)-1)
	}
	for i := 0; i < len(m.rows)*2; i++ {
		m = key(t, m, tea.KeyMsg{Type: tea.KeyUp})
	}
	if m.cursor != 0 {
		t.Fatalf("cursor = %d, want 0", m.cursor)
	}
}

func TestLaptopVariantAddsThermaldStep(t *testing.T) {
	m := newTestModel()
	m.width, m.height = 100, 40
	m = key(t, m, tea.KeyMsg{Type: tea.KeyDown}) // desktop -> laptop
	if m.variant != config.VariantLaptop {
		t.Fatalf("variant = %v, want laptop", m.variant)
	}
	m = enter(t, m)

	ids := map[string]bool{}
	for _, r := range m.rows {
		if !r.isGroup {
			ids[r.step.ID] = true
		}
	}
	if !ids["services-laptop"] {
		t.Error("laptop variant should include the thermald step")
	}
}

func TestDoneViewSummarisesResults(t *testing.T) {
	m := newTestModel()
	m.stage = stageDone
	m.results = []plan.Result{
		{Step: plan.Step{Title: "ok step"}, Status: plan.StatusOK},
		{Step: plan.Step{Title: "broke"}, Status: plan.StatusFailed, Err: errFailed},
	}
	view := m.View()
	if !strings.Contains(view, "finished with failures") || !strings.Contains(view, "broke") {
		t.Errorf("done view missing failure summary:\n%s", view)
	}
}

type failErr struct{}

func (failErr) Error() string { return "boom" }

var errFailed = failErr{}
