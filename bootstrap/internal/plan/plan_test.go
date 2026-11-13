package plan

import (
	"errors"
	"io"
	"testing"

	"dotfiles/bootstrap/internal/run"
)

func testEnv() *Env {
	return &Env{Run: &run.Runner{Out: io.Discard}}
}

func TestExecuteSkipsSatisfiedStepsAndKeepsGoing(t *testing.T) {
	var ran []string
	boom := errors.New("boom")

	steps := []Step{
		{
			ID:    "already",
			Check: func(*Env) bool { return true },
			Run:   func(*Env) error { ran = append(ran, "already"); return nil },
		},
		{
			ID:  "runs",
			Run: func(*Env) error { ran = append(ran, "runs"); return nil },
		},
		{
			ID:       "optional",
			Optional: true,
			Run:      func(*Env) error { return boom },
		},
		{
			ID:  "fails",
			Run: func(*Env) error { return boom },
		},
		{
			ID:  "after",
			Run: func(*Env) error { ran = append(ran, "after"); return nil },
		},
	}

	results := Execute(steps, testEnv(), nil)
	if len(results) != len(steps) {
		t.Fatalf("got %d results, want %d", len(results), len(steps))
	}
	if results[0].Status != StatusSkipped {
		t.Errorf("satisfied step status = %v, want skipped", results[0].Status)
	}
	if results[2].Status != StatusWarned {
		t.Errorf("optional failure status = %v, want warned", results[2].Status)
	}
	if results[3].Status != StatusFailed {
		t.Errorf("required failure status = %v, want failed", results[3].Status)
	}
	if len(ran) != 2 || ran[0] != "runs" || ran[1] != "after" {
		t.Errorf("ran = %v, want [runs after] (skipped step must not run, failure must not stop the run)", ran)
	}

	ok, skipped, warned, failed := Tally(results)
	if ok != 2 || skipped != 1 || warned != 1 || failed != 1 {
		t.Errorf("tally = %d/%d/%d/%d", ok, skipped, warned, failed)
	}
}

func TestExecuteEmitsProgressInOrder(t *testing.T) {
	steps := []Step{
		{ID: "one", Run: func(*Env) error { return nil }},
		{ID: "skipped", Check: func(*Env) bool { return true }, Run: func(*Env) error { return nil }},
		{ID: "two", Run: func(*Env) error { return nil }},
	}

	var kinds []EventKind
	Execute(steps, testEnv(), func(ev Event) {
		kinds = append(kinds, ev.Kind)
		if ev.Total != len(steps) {
			t.Errorf("event total = %d, want %d", ev.Total, len(steps))
		}
	})

	want := []EventKind{EventStart, EventDone, EventSkip, EventStart, EventDone, EventFinished}
	if len(kinds) != len(want) {
		t.Fatalf("events = %v, want %v", kinds, want)
	}
	for i := range want {
		if kinds[i] != want[i] {
			t.Fatalf("events = %v, want %v", kinds, want)
		}
	}
}

func TestSelection(t *testing.T) {
	steps := []Step{
		{ID: "base", Group: GroupSystem},
		{ID: "opt", Group: GroupSystem, OptIn: true},
		{ID: "links", Group: GroupDotfiles},
	}

	if got := len(Selection{}.Pick(steps)); got != 2 {
		t.Errorf("default selection = %d steps, want 2 (opt-in excluded)", got)
	}
	if got := len((Selection{Groups: []string{"dotfiles"}}).Pick(steps)); got != 1 {
		t.Errorf("group filter = %d steps, want 1", got)
	}
	if got := len((Selection{Only: []string{"opt"}}).Pick(steps)); got != 1 {
		t.Errorf("only filter = %d steps, want 1 (opt-in allowed when named)", got)
	}
	if got := len((Selection{Exclude: []string{"base"}}).Pick(steps)); got != 1 {
		t.Errorf("exclude = %d steps, want 1", got)
	}
	if got := len((Selection{Include: []string{"opt"}}).Pick(steps)); got != 3 {
		t.Errorf("include = %d steps, want 3", got)
	}
}
