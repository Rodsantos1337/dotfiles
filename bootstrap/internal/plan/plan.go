// Package plan defines the step model and runs a step list. A step knows how
// to check itself and how to apply itself, which is what makes dry-run,
// resume and re-run all the same code path.
package plan

import (
	"fmt"
	"io"
	"time"

	"dotfiles/bootstrap/internal/config"
	"dotfiles/bootstrap/internal/run"
)

// Group is a selectable cluster of steps in the TUI.
type Group string

const (
	GroupSystem      Group = "system"
	GroupPackages    Group = "packages"
	GroupApps        Group = "apps"
	GroupAuth        Group = "auth"
	GroupDev         Group = "dev"
	GroupDotfiles    Group = "dotfiles"
	GroupDesktop     Group = "desktop"
	GroupServices    Group = "services"
	GroupMaintenance Group = "maintenance"
)

// Groups is the display order.
var Groups = []Group{
	GroupSystem, GroupPackages, GroupApps, GroupAuth, GroupDev,
	GroupDotfiles, GroupDesktop, GroupServices, GroupMaintenance,
}

// GroupTitles are the human labels shown in the TUI.
var GroupTitles = map[Group]string{
	GroupSystem:      "system repositories",
	GroupPackages:    "packages",
	GroupApps:        "apps & fonts",
	GroupAuth:        "accounts",
	GroupDev:         "dev tooling",
	GroupDotfiles:    "dotfiles",
	GroupDesktop:     "desktop",
	GroupServices:    "services",
	GroupMaintenance: "maintenance",
}

// Step is one idempotent unit of provisioning.
type Step struct {
	ID    string
	Group Group
	Title string

	NeedsRoot bool // sudo is primed before this step runs
	Optional  bool // failures are warnings, not fatal
	OptIn     bool // not selected unless explicitly requested

	// Check reports whether the step's outcome already holds. A nil Check
	// means "always run".
	Check func(*Env) bool

	Run func(*Env) error
}

// Env is what a step gets to work with.
type Env struct {
	Cfg config.Config
	Run *run.Runner
}

// Printf writes a line to the live view.
func (e *Env) Printf(format string, a ...any) { e.Run.Printf(format, a...) }

// Out is the live output sink.
func (e *Env) Out() io.Writer { return e.Run.Out }

// Status is the outcome of one step.
type Status int

const (
	StatusOK Status = iota
	StatusSkipped
	StatusWarned
	StatusFailed
)

func (s Status) String() string {
	switch s {
	case StatusOK:
		return "done"
	case StatusSkipped:
		return "already done"
	case StatusWarned:
		return "warning"
	default:
		return "failed"
	}
}

// Result is a finished step.
type Result struct {
	Step     Step
	Status   Status
	Err      error
	Duration time.Duration
}

// EventKind labels progress events sent to a view.
type EventKind int

const (
	EventStart EventKind = iota
	EventSkip
	EventDone
	EventFinished
)

// Event is one progress notification.
type Event struct {
	Kind    EventKind
	Index   int // 1-based
	Total   int
	Step    Step
	Result  *Result
	Results []Result
}

// Selection chooses steps from the full list.
type Selection struct {
	Groups  []string // empty means every group
	Only    []string // if set, only these step IDs
	Exclude []string
	Include []string // force these IDs on
}

// Keep reports whether a step is selected.
func (s Selection) Keep(step Step) bool {
	if contains(s.Exclude, step.ID) {
		return false
	}
	if contains(s.Include, step.ID) {
		return true
	}
	if len(s.Only) > 0 {
		return contains(s.Only, step.ID)
	}
	if len(s.Groups) > 0 {
		return contains(s.Groups, string(step.Group))
	}
	return !step.OptIn
}

// Pick filters the step list through a selection.
func (s Selection) Pick(steps []Step) []Step {
	out := make([]Step, 0, len(steps))
	for _, step := range steps {
		if s.Keep(step) {
			out = append(out, step)
		}
	}
	return out
}

// Execute runs the steps in order, reporting progress through hook. It never
// stops early: a failure is recorded and the run continues, so one broken
// optional tool does not abandon the rest of the machine.
func Execute(steps []Step, env *Env, hook func(Event)) []Result {
	results := make([]Result, 0, len(steps))
	total := len(steps)

	for i, step := range steps {
		index := i + 1

		if step.Check != nil && step.Check(env) {
			res := Result{Step: step, Status: StatusSkipped}
			results = append(results, res)
			if hook != nil {
				hook(Event{Kind: EventSkip, Index: index, Total: total, Step: step, Result: &res})
			}
			continue
		}

		if hook != nil {
			hook(Event{Kind: EventStart, Index: index, Total: total, Step: step})
		}

		start := time.Now()
		err := step.Run(env)
		res := Result{Step: step, Status: StatusOK, Duration: time.Since(start).Round(100 * time.Millisecond)}
		if err != nil {
			res.Err = err
			res.Status = StatusFailed
			if step.Optional {
				res.Status = StatusWarned
			}
		}
		results = append(results, res)
		if hook != nil {
			hook(Event{Kind: EventDone, Index: index, Total: total, Step: step, Result: &res})
		}
	}

	if hook != nil {
		hook(Event{Kind: EventFinished, Total: total, Results: results})
	}
	return results
}

// Tally counts results by status.
func Tally(results []Result) (ok, skipped, warned, failed int) {
	for _, res := range results {
		switch res.Status {
		case StatusOK:
			ok++
		case StatusSkipped:
			skipped++
		case StatusWarned:
			warned++
		case StatusFailed:
			failed++
		}
	}
	return
}

// Failures returns the results that did not succeed outright.
func Failures(results []Result) []Result {
	var out []Result
	for _, res := range results {
		if res.Status == StatusFailed || res.Status == StatusWarned {
			out = append(out, res)
		}
	}
	return out
}

// Summary renders a one-line tally.
func Summary(results []Result) string {
	ok, skipped, warned, failed := Tally(results)
	return fmt.Sprintf("%d done, %d skipped, %d warned, %d failed", ok, skipped, warned, failed)
}

func contains(list []string, s string) bool {
	for _, item := range list {
		if item == s {
			return true
		}
	}
	return false
}
