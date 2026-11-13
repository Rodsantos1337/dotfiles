// Package run executes commands: streamed to the log and the view, with sudo
// handled once per root step instead of per command.
package run

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// Runner is the single command executor. Out is where live output goes
// (stdout or the TUI viewport); Log mirrors it to the run log file.
type Runner struct {
	Out    io.Writer
	Log    io.Writer
	DryRun bool

	// Sudo is called when a root command needs a valid sudo timestamp.
	// The TUI implements this by running `sudo -v` with the terminal.
	Sudo func() error

	// Interactive runs a command that needs the terminal (device logins,
	// `tailscale up`). The TUI runs it via tea.ExecProcess.
	Interactive func(name string, args ...string) error

	mu sync.Mutex
}

// Printf writes to the live view only.
func (r *Runner) Printf(format string, a ...any) {
	r.mu.Lock()
	defer r.mu.Unlock()
	fmt.Fprintf(r.out(), format, a...)
}

func (r *Runner) out() io.Writer {
	if r.Out != nil {
		return r.Out
	}
	return os.Stdout
}

func (r *Runner) sink() io.Writer {
	if r.Log == nil {
		return r.out()
	}
	return io.MultiWriter(r.out(), r.Log)
}

func (r *Runner) logf(format string, a ...any) {
	if r.Log == nil {
		return
	}
	fmt.Fprintf(r.Log, format, a...)
}

// Run executes a command as the current user.
func (r *Runner) Run(name string, args ...string) error {
	return r.stream(false, name, args)
}

// Root executes a command as root through `sudo -n`, priming the sudo
// timestamp first when it has expired.
func (r *Runner) Root(name string, args ...string) error {
	if err := r.ensureSudo(); err != nil {
		return err
	}
	return r.stream(true, name, args)
}

// Script runs a bash script as the current user.
func (r *Runner) Script(script string) error {
	return r.stream(false, "bash", []string{"-c", script})
}

// RootScript runs a bash script as root.
func (r *Runner) RootScript(script string) error {
	if err := r.ensureSudo(); err != nil {
		return err
	}
	return r.stream(true, "bash", []string{"-c", script})
}

// Attach runs a command attached to the terminal (interactive by nature).
func (r *Runner) Attach(name string, args ...string) error {
	return r.attach(false, name, args)
}

// AttachRoot is Attach with sudo.
func (r *Runner) AttachRoot(name string, args ...string) error {
	if err := r.ensureSudo(); err != nil {
		return err
	}
	return r.attach(true, name, args)
}

// Capture runs a command and returns its combined output. Used by checks, so
// it runs even in dry-run mode.
func (r *Runner) Capture(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	out, err := cmd.CombinedOutput()
	r.logf("$ %s\n%s\n", cmdline(name, args), out)
	return string(out), err
}

// RootCapture is Capture with sudo -n.
func (r *Runner) RootCapture(name string, args ...string) (string, error) {
	if err := r.ensureSudo(); err != nil {
		return "", err
	}
	name, args = sudoWrap(name, args)
	return r.Capture(name, args...)
}

// OK reports whether a command exits successfully.
func (r *Runner) OK(name string, args ...string) bool {
	_, err := r.Capture(name, args...)
	return err == nil
}

// Has reports whether a command is on PATH.
func (r *Runner) Has(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func (r *Runner) stream(root bool, name string, args []string) error {
	if root {
		name, args = sudoWrap(name, args)
	}
	line := cmdline(name, args)
	if r.DryRun {
		r.Printf("+ %s\n", line)
		r.logf("$ %s (dry-run)\n", line)
		return nil
	}
	r.Printf("$ %s\n", line)
	r.logf("\n=== %s %s ===\n", time.Now().Format(time.RFC3339), line)

	cmd := exec.Command(name, args...)
	cmd.Stdout = r.sink()
	cmd.Stderr = r.sink()
	err := cmd.Run()
	if err != nil {
		r.Printf("! %s\n", line)
	}
	return err
}

func (r *Runner) attach(root bool, name string, args []string) error {
	if root {
		name, args = sudoWrap(name, args)
	}
	line := cmdline(name, args)
	if r.DryRun {
		r.Printf("+ %s\n", line)
		return nil
	}
	if r.Interactive != nil {
		r.logf("\n=== %s (interactive) %s ===\n", time.Now().Format(time.RFC3339), line)
		return r.Interactive(name, args...)
	}
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func (r *Runner) ensureSudo() error {
	if r.DryRun {
		return nil
	}
	if exec.Command("sudo", "-n", "true").Run() == nil {
		return nil
	}
	if r.Sudo == nil {
		return fmt.Errorf("sudo: no valid timestamp and no way to prompt")
	}
	if err := r.Sudo(); err != nil {
		return fmt.Errorf("sudo: %w", err)
	}
	return nil
}

func sudoWrap(name string, args []string) (string, []string) {
	return "sudo", append([]string{"-n", name}, args...)
}

func cmdline(name string, args []string) string {
	if len(args) == 0 {
		return name
	}
	return name + " " + strings.Join(args, " ")
}

// OpenLog creates the run log under ~/.local/state/dotfiles-bootstrap.
func OpenLog() (io.WriteCloser, string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, "", err
	}
	dir := filepath.Join(home, ".local", "state", "dotfiles-bootstrap")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, "", err
	}
	path := filepath.Join(dir, "run-"+time.Now().Format("20060102-150405")+".log")
	f, err := os.Create(path)
	if err != nil {
		return nil, "", err
	}
	return f, path, nil
}
