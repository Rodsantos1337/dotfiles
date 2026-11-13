// Command bootstrap provisions a Fedora machine from the dotfiles repo:
// packages, accounts, dotfile symlinks, theming and services.
//
//	bootstrap                 interactive TUI (or plain when piped)
//	bootstrap plan            list every step
//	bootstrap apply           run steps without a TUI
//	bootstrap link            only the symlink step
//	bootstrap verify          only check the symlinks
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"dotfiles/bootstrap/internal/config"
	"dotfiles/bootstrap/internal/detect"
	"dotfiles/bootstrap/internal/link"
	"dotfiles/bootstrap/internal/plan"
	"dotfiles/bootstrap/internal/run"
	"dotfiles/bootstrap/internal/tui"
)

const version = "0.2.0"

// commit is stamped into the binary at build time so an old pendrive build is
// visible in `bootstrap version`.
var commit = "dev"

func main() {
	if err := dispatch(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "\nerror: %v\n", err)
		os.Exit(1)
	}
}

func dispatch(args []string) error {
	cmd := "tui"
	if len(args) > 0 && !strings.HasPrefix(args[0], "-") {
		cmd, args = args[0], args[1:]
	}

	switch cmd {
	case "tui", "install", "run":
		return cmdTUI(args)
	case "apply":
		return cmdApply(args)
	case "plan":
		return cmdPlan(args)
	case "link":
		return cmdLink(args)
	case "verify":
		return cmdVerify(args)
	case "version":
		fmt.Printf("bootstrap %s (%s, %s/%s)\n", version, commit, runtime.GOOS, runtime.GOARCH)
		return nil
	case "help":
		usage()
		return nil
	default:
		usage()
		return fmt.Errorf("unknown command %q", cmd)
	}
}

// flags are the options shared by the commands.
type flags struct {
	variant     string
	desktop     bool
	laptop      bool
	dotfilesDir string
	dryRun      bool
	noTUI       bool
	groups      string
	only        string
	exclude     string
	upgrade     bool
	privatize   bool
}

func bindCommon(fs *flag.FlagSet, f *flags) {
	fs.StringVar(&f.variant, "variant", "", "machine variant: desktop or laptop (default: detect)")
	fs.BoolVar(&f.desktop, "desktop", false, "shorthand for --variant desktop")
	fs.BoolVar(&f.laptop, "laptop", false, "shorthand for --variant laptop")
	fs.StringVar(&f.dotfilesDir, "dotfiles-dir", "", "where the repo lives (default $HOME/dotfiles)")
	fs.BoolVar(&f.dryRun, "dry-run", false, "print what would run, change nothing")
	fs.BoolVar(&f.noTUI, "no-tui", false, "plain output instead of the interactive UI")
}

func bindSelection(fs *flag.FlagSet, f *flags) {
	fs.StringVar(&f.groups, "groups", "", "comma-separated groups to run (system,packages,apps,auth,dev,dotfiles,desktop,services,maintenance)")
	fs.StringVar(&f.only, "only", "", "comma-separated step IDs to run")
	fs.StringVar(&f.exclude, "exclude", "", "comma-separated step IDs to skip")
	fs.BoolVar(&f.upgrade, "upgrade", false, "include the full dnf system upgrade (slow)")
	fs.BoolVar(&f.privatize, "privatize", false, "set the dotfiles repo to private at the end")
}

func (f flags) variantOrDefault() (config.Variant, error) {
	switch {
	case f.desktop && f.laptop:
		return "", fmt.Errorf("--desktop and --laptop are mutually exclusive")
	case f.desktop:
		return config.VariantDesktop, nil
	case f.laptop:
		return config.VariantLaptop, nil
	case f.variant != "":
		v, ok := config.ParseVariant(f.variant)
		if !ok {
			return "", fmt.Errorf("unknown variant %q (want desktop or laptop)", f.variant)
		}
		return v, nil
	}
	return detect.Variant(), nil
}

func (f flags) buildConfig(v config.Variant) config.Config {
	cfg := config.BuildConfig(v)
	if f.dotfilesDir != "" {
		cfg.DotfilesDir = expand(f.dotfilesDir)
	}
	return cfg
}

func (f flags) selection() plan.Selection {
	sel := plan.Selection{
		Groups:  splitList(f.groups),
		Only:    splitList(f.only),
		Exclude: splitList(f.exclude),
	}
	if f.upgrade {
		sel.Include = append(sel.Include, "dnf-upgrade")
	}
	if f.privatize {
		sel.Include = append(sel.Include, "privatize")
	}
	return sel
}

// ------------------------------------------------------------------ commands

func cmdTUI(args []string) error {
	fs := flag.NewFlagSet("tui", flag.ContinueOnError)
	var f flags
	bindCommon(fs, &f)
	bindSelection(fs, &f)
	if err := fs.Parse(args); err != nil {
		return err
	}
	v, err := f.variantOrDefault()
	if err != nil {
		return err
	}
	cfg := f.buildConfig(v)

	if f.dryRun || f.noTUI || !isTTY() {
		return applyPlain(cfg, f)
	}
	if !detect.Fedora() {
		fmt.Fprintln(os.Stderr, "warning: this does not look like Fedora; the package steps will fail")
	}
	return tui.Run(tui.Options{
		Cfg:         cfg,
		Detected:    detect.Variant(),
		DotfilesDir: f.dotfilesDir,
		Upgrade:     f.upgrade,
		Privatize:   f.privatize,
	})
}

func cmdApply(args []string) error {
	fs := flag.NewFlagSet("apply", flag.ContinueOnError)
	var f flags
	bindCommon(fs, &f)
	bindSelection(fs, &f)
	if err := fs.Parse(args); err != nil {
		return err
	}
	v, err := f.variantOrDefault()
	if err != nil {
		return err
	}
	return applyPlain(f.buildConfig(v), f)
}

func cmdPlan(args []string) error {
	fs := flag.NewFlagSet("plan", flag.ContinueOnError)
	var f flags
	bindCommon(fs, &f)
	bindSelection(fs, &f)
	if err := fs.Parse(args); err != nil {
		return err
	}
	v, err := f.variantOrDefault()
	if err != nil {
		return err
	}
	cfg := f.buildConfig(v)
	sel := f.selection()

	fmt.Printf("variant: %s   dotfiles: %s\n", v, cfg.DotfilesDir)
	fmt.Printf("%-4s %-3s %-5s %-22s %s\n", "on", "root", "opt", "step", "title")
	current := plan.Group("")
	on, total := 0, 0
	for _, step := range plan.All(cfg) {
		total++
		selected := sel.Keep(step)
		if selected {
			on++
		}
		if step.Group != current {
			current = step.Group
			fmt.Printf("\n# %s\n", plan.GroupTitles[current])
		}
		mark := " "
		if selected {
			mark = "x"
		}
		fmt.Printf("%-4s %-3s %-5s %-22s %s\n",
			mark,
			yesNo(step.NeedsRoot),
			yesNo(step.OptIn),
			step.ID,
			step.Title,
		)
	}
	fmt.Printf("\n%d of %d steps selected\n", on, total)
	return nil
}

func cmdLink(args []string) error {
	fs := flag.NewFlagSet("link", flag.ContinueOnError)
	var f flags
	bindCommon(fs, &f)
	if err := fs.Parse(args); err != nil {
		return err
	}
	v, err := f.variantOrDefault()
	if err != nil {
		return err
	}
	cfg := f.buildConfig(v)

	fmt.Printf("linking %d paths from %s into %s\n", len(cfg.Mappings), cfg.DotfilesDir, cfg.Home)
	return executeSteps(plan.LinkSteps(cfg), cfg, f.dryRun, true)
}

func cmdVerify(args []string) error {
	fs := flag.NewFlagSet("verify", flag.ContinueOnError)
	var f flags
	bindCommon(fs, &f)
	if err := fs.Parse(args); err != nil {
		return err
	}
	v, err := f.variantOrDefault()
	if err != nil {
		return err
	}
	cfg := f.buildConfig(v)

	opts := link.Options{DotfilesDir: cfg.DotfilesDir, Home: cfg.Home}
	failures := opts.Verify(cfg.Mappings)
	broken := make(map[string]bool, len(failures))
	for _, failure := range failures {
		broken[failure.Rel] = true
	}
	for _, mapping := range cfg.Mappings {
		homeRel := mapping.HomeRel
		if homeRel == "" {
			homeRel = mapping.RepoRel
		}
		if broken[homeRel] {
			fmt.Printf("MISS  %s\n", homeRel)
			continue
		}
		fmt.Printf("ok    %s\n", homeRel)
	}
	if len(failures) > 0 {
		return fmt.Errorf("%d of %d paths are not linked (run: bootstrap link)", len(failures), len(cfg.Mappings))
	}
	fmt.Printf("all %d paths are linked\n", len(cfg.Mappings))
	return nil
}

// ------------------------------------------------------------------- running

func applyPlain(cfg config.Config, f flags) error {
	steps := f.selection().Pick(plan.All(cfg))
	if len(steps) == 0 {
		return fmt.Errorf("nothing selected")
	}
	fmt.Printf("variant: %s   steps: %d\n\n", cfg.Variant, len(steps))
	return executeSteps(steps, cfg, f.dryRun, f.dryRun)
}

func executeSteps(steps []plan.Step, cfg config.Config, dryRun, verbose bool) error {
	total := len(steps)
	runner := &run.Runner{Out: os.Stdout, DryRun: dryRun}
	runner.Sudo = func() error {
		cmd := exec.Command("sudo", "-v")
		cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
		return cmd.Run()
	}
	if logFile, path, err := run.OpenLog(); err == nil {
		runner.Log = logFile
		defer logFile.Close()
		if verbose {
			fmt.Printf("log: %s\n\n", path)
		}
	}

	env := &plan.Env{Cfg: cfg, Run: runner}
	results := plan.Execute(steps, env, func(ev plan.Event) {
		switch ev.Kind {
		case plan.EventStart:
			fmt.Printf("==> [%*d/%d] %s\n", len(fmt.Sprint(total)), ev.Index, total, ev.Step.Title)
		case plan.EventSkip:
			fmt.Printf("    skipped (already done)\n")
		case plan.EventDone:
			switch ev.Result.Status {
			case plan.StatusOK:
				fmt.Printf("    done in %s\n", ev.Result.Duration)
			case plan.StatusWarned:
				fmt.Printf("    warning: %v\n", ev.Result.Err)
			default:
				fmt.Printf("    FAILED: %v\n", ev.Result.Err)
			}
		}
	})

	fmt.Printf("\n%s\n", plan.Summary(results))
	if failures := plan.Failures(results); len(failures) > 0 {
		for _, res := range failures {
			fmt.Printf("  %-14s %v\n", res.Step.ID, res.Err)
		}
	}
	for _, res := range results {
		if res.Status == plan.StatusFailed {
			return fmt.Errorf("%d step(s) failed", countStatus(results, plan.StatusFailed))
		}
	}
	return nil
}

func countStatus(results []plan.Result, status plan.Status) int {
	n := 0
	for _, res := range results {
		if res.Status == status {
			n++
		}
	}
	return n
}

// --------------------------------------------------------------------- utils

func splitList(s string) []string {
	var out []string
	for _, part := range strings.Split(s, ",") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

func yesNo(b bool) string {
	if b {
		return "yes"
	}
	return "-"
}

// expand resolves ~ and normalises the path, so symlink targets and the
// verify prefix are compared as the same string.
func expand(p string) string {
	if strings.HasPrefix(p, "~") {
		home, _ := os.UserHomeDir()
		p = home + strings.TrimPrefix(p, "~")
	}
	if abs, err := filepath.Abs(p); err == nil {
		p = abs
	}
	return filepath.Clean(p)
}

func isTTY() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

func usage() {
	fmt.Print(`bootstrap - provision this Fedora machine from the dotfiles repo

Usage:
  bootstrap [flags]              interactive TUI (plain output when piped)
  bootstrap plan    [flags]      list every step and whether it is selected
  bootstrap apply   [flags]      run the selected steps, no TUI
  bootstrap link    [flags]      only create the dotfile symlinks
  bootstrap verify  [flags]      only check the dotfile symlinks
  bootstrap version

Flags:
  --variant desktop|laptop   machine variant (also --desktop / --laptop)
  --dotfiles-dir PATH        where the repo lives (default $HOME/dotfiles)
  --groups LIST              run whole groups: system,packages,apps,auth,
                             dev,dotfiles,desktop,services,maintenance
  --only LIST                run exactly these step IDs
  --exclude LIST             skip these step IDs
  --upgrade                  include the full dnf system upgrade (slow)
  --privatize                set the dotfiles repo to private at the end
  --dry-run                  print the commands, change nothing
  --no-tui                   plain output instead of the interactive UI

Examples:
  bootstrap                                  # pick desktop/laptop in the TUI
  bootstrap apply --laptop                   # unattended on a laptop
  bootstrap apply --dry-run --laptop         # see what would happen
  bootstrap link --desktop                   # symlinks only
`)
}
