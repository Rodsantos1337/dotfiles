// Package link owns the single symlink primitive the whole tool uses.
package link

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"dotfiles/bootstrap/internal/config"
)

// Action describes what happened to one mapping.
type Action string

const (
	ActionLink   Action = "link"
	ActionOK     Action = "ok"
	ActionSkip   Action = "skip"
	ActionBackup Action = "back"
)

// Options carries the paths one link run works against.
type Options struct {
	DotfilesDir string
	Home        string
	BackupDir   string
	DryRun      bool
	OnResult    func(Result)
}

// Result is the outcome for one mapping.
type Result struct {
	Rel      string
	Src      string
	Dest     string
	Action   Action
	BackupTo string
}

// Failure is one broken link found by Verify.
type Failure struct {
	Rel    string
	Dest   string
	Target string
}

// Ensure creates dest as a symlink to src, backing up anything in the way.
// It is idempotent: a link that already points at src is left alone.
func (o Options) Ensure(repoRel, homeRel string) (Result, error) {
	if homeRel == "" {
		homeRel = repoRel
	}
	src := filepath.Join(o.DotfilesDir, repoRel)
	dest := filepath.Join(o.Home, homeRel)
	res := Result{Rel: homeRel, Src: src, Dest: dest}

	if !pathExists(src) {
		res.Action = ActionSkip
		return res, nil
	}
	if IsLinkTo(dest, src) {
		res.Action = ActionOK
		return res, nil
	}

	if pathExists(dest) || isLink(dest) {
		if o.BackupDir == "" {
			return res, fmt.Errorf("refusing to overwrite %s without a backup dir", dest)
		}
		backupTo := filepath.Join(o.BackupDir, homeRel)
		res.BackupTo = backupTo
		res.Action = ActionBackup
		if !o.DryRun {
			if err := os.MkdirAll(filepath.Dir(backupTo), 0o755); err != nil {
				return res, fmt.Errorf("create backup parent: %w", err)
			}
			if err := os.Rename(dest, backupTo); err != nil {
				return res, fmt.Errorf("back up %s: %w", dest, err)
			}
		}
	}

	if res.Action != ActionBackup {
		res.Action = ActionLink
	}
	if o.DryRun {
		return res, nil
	}
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return res, fmt.Errorf("create parent %s: %w", filepath.Dir(dest), err)
	}
	if err := os.Symlink(src, dest); err != nil {
		return res, fmt.Errorf("symlink %s -> %s: %w", dest, src, err)
	}
	return res, nil
}

// All links every mapping in order, reporting each result as it happens.
// A broken mapping does not stop the run; the first error is returned at the end.
func (o Options) All(mappings []config.Mapping) ([]Result, error) {
	results := make([]Result, 0, len(mappings))
	var firstErr error
	for _, m := range mappings {
		res, err := o.Ensure(m.RepoRel, m.HomeRel)
		results = append(results, res)
		if o.OnResult != nil {
			o.OnResult(res)
		}
		if err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return results, firstErr
}

// Verify reports every mapping whose destination is not a symlink into
// DotfilesDir. Mappings whose source is absent from the repo are ignored,
// because the link step skips those on purpose.
func (o Options) Verify(mappings []config.Mapping) []Failure {
	var failures []Failure
	for _, m := range mappings {
		homeRel := m.HomeRel
		if homeRel == "" {
			homeRel = m.RepoRel
		}
		src := filepath.Join(o.DotfilesDir, m.RepoRel)
		if !pathExists(src) {
			continue
		}
		dest := filepath.Join(o.Home, homeRel)
		target, err := os.Readlink(dest)
		if err != nil || !within(o.DotfilesDir, target) {
			failures = append(failures, Failure{Rel: homeRel, Dest: dest, Target: target})
		}
	}
	return failures
}

// IsLinkTo reports whether dest is a symlink pointing at src.
func IsLinkTo(dest, src string) bool {
	target, err := os.Readlink(dest)
	if err != nil {
		return false
	}
	return target == src
}

func within(dir, target string) bool {
	return target == dir || strings.HasPrefix(target, dir+string(os.PathSeparator))
}

func pathExists(p string) bool {
	_, err := os.Lstat(p)
	return err == nil
}

func isLink(p string) bool {
	fi, err := os.Lstat(p)
	return err == nil && fi.Mode()&os.ModeSymlink != 0
}
