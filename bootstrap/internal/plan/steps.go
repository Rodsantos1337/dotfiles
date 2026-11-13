package plan

import (
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"dotfiles/bootstrap/internal/config"
	"dotfiles/bootstrap/internal/link"
)

var stalePathRE = regexp.MustCompile(`/home/[A-Za-z0-9._-]+/`)

// All builds the complete step list for a variant, in execution order.
func All(cfg config.Config) []Step {
	home := cfg.Home
	dotfiles := cfg.DotfilesDir
	user := currentUser()

	steps := []Step{
		// ---------------------------------------------------------------- system
		{
			ID:        "rpmfusion",
			Group:     GroupSystem,
			Title:     "enable RPM Fusion",
			NeedsRoot: true,
			Check: func(e *Env) bool {
				return exists("/etc/yum.repos.d/rpmfusion-free.repo") &&
					exists("/etc/yum.repos.d/rpmfusion-nonfree.repo")
			},
			Run: func(e *Env) error {
				out, err := e.Run.Capture("rpm", "-E", "%fedora")
				ver := strings.TrimSpace(out)
				if err != nil || ver == "" || strings.Contains(ver, "%") {
					return fmt.Errorf("cannot determine the Fedora release")
				}
				free := fmt.Sprintf(config.RPMFusionFree, ver)
				nonfree := fmt.Sprintf(config.RPMFusionNonFree, ver)
				return e.Run.Root("dnf", "install", "-y", free, nonfree)
			},
		},
		{
			ID:        "copr-zen",
			Group:     GroupSystem,
			Title:     "enable the Zen browser COPR",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				out, err := e.Run.Capture("dnf", "copr", "list", "--enabled")
				return err == nil && strings.Contains(out, config.CoprMarker)
			},
			Run: func(e *Env) error {
				return e.Run.Root("dnf", "copr", "enable", "-y", config.CoprRepo)
			},
		},

		// -------------------------------------------------------------- packages
		{
			ID:        "dnf-upgrade",
			Group:     GroupPackages,
			Title:     "full system upgrade (slow)",
			NeedsRoot: true,
			OptIn:     true,
			Run: func(e *Env) error {
				return e.Run.Root("dnf", "upgrade", "--refresh", "-y")
			},
		},
		{
			ID:        "dnf-pkgs",
			Group:     GroupPackages,
			Title:     fmt.Sprintf("install %d dnf packages", len(cfg.DNFPkgs)),
			NeedsRoot: true,
			Check: func(e *Env) bool {
				_, err := e.Run.Capture("rpm", append([]string{"-q"}, cfg.DNFPkgs...)...)
				return err == nil
			},
			Run: func(e *Env) error {
				return e.Run.Root("dnf", append([]string{"install", "-y"}, cfg.DNFPkgs...)...)
			},
		},
		{
			ID:        "third-party-pkgs",
			Group:     GroupPackages,
			Title:     "install " + strings.Join(cfg.ThirdPartyPkgs, ", "),
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				for _, pkg := range cfg.ThirdPartyPkgs {
					if !e.Run.OK("rpm", "-q", pkg) {
						return false
					}
				}
				return true
			},
			Run: func(e *Env) error {
				return e.Run.Root("dnf", append([]string{"install", "-y"}, cfg.ThirdPartyPkgs...)...)
			},
		},

		// ------------------------------------------------------------ accounts
		{
			ID:    "git-identity",
			Group: GroupAuth,
			Title: "set git name and email",
			Check: func(e *Env) bool {
				name, err1 := e.Run.Capture("git", "config", "--global", "user.name")
				email, err2 := e.Run.Capture("git", "config", "--global", "user.email")
				return err1 == nil && err2 == nil &&
					strings.TrimSpace(name) == config.GitName &&
					strings.TrimSpace(email) == config.GitEmail
			},
			Run: func(e *Env) error {
				if err := e.Run.Run("git", "config", "--global", "user.name", config.GitName); err != nil {
					return err
				}
				return e.Run.Run("git", "config", "--global", "user.email", config.GitEmail)
			},
		},
		{
			ID:    "gh-auth",
			Group: GroupAuth,
			Title: "log in to GitHub",
			Check: func(e *Env) bool {
				return e.Run.Has("gh") && e.Run.OK("gh", "auth", "status")
			},
			Run: func(e *Env) error {
				if err := e.Run.Attach("gh", "auth", "login", "-w", "-p", "https", "-h", "github.com"); err != nil {
					return fmt.Errorf("gh auth login: %w", err)
				}
				_ = e.Run.Run("gh", "auth", "setup-git", "--hostname", "github.com")
				return nil
			},
		},
		{
			ID:        "tailscale-auth",
			Group:     GroupAuth,
			Title:     "join the tailnet (tailscale up)",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				if !e.Run.Has("tailscale") {
					return true
				}
				return e.Run.OK("sudo", "-n", "tailscale", "status")
			},
			Run: func(e *Env) error {
				return e.Run.AttachRoot("tailscale", "up")
			},
		},

		// ---------------------------------------------------------------- apps
		{
			ID:        "tailscale",
			Group:     GroupApps,
			Title:     "install Tailscale",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				return e.Run.Has("tailscale")
			},
			Run: func(e *Env) error {
				return e.Run.RootScript("curl -fsSL " + config.TailscaleInstaller + " | sh")
			},
		},
		{
			ID:       "opencode",
			Group:    GroupApps,
			Title:    "install opencode",
			Optional: true,
			Check: func(e *Env) bool {
				return e.Run.Has("opencode")
			},
			Run: func(e *Env) error {
				return e.Run.Script("curl -fsSL " + config.OpencodeInstaller + " | bash")
			},
		},
		{
			ID:        "nerd-fonts",
			Group:     GroupApps,
			Title:     "install Nerd Fonts (" + strings.Join(cfg.NerdFonts, ", ") + ")",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				out, err := e.Run.Capture("fc-list")
				if err != nil {
					return false
				}
				for _, font := range cfg.NerdFonts {
					if !strings.Contains(out, font+" Nerd") {
						return false
					}
				}
				return true
			},
			Run: func(e *Env) error {
				var b strings.Builder
				b.WriteString("set -e\n")
				b.WriteString("tmp=$(mktemp -d)\n")
				b.WriteString("mkdir -p /usr/local/share/fonts\n")
				for _, font := range cfg.NerdFonts {
					fmt.Fprintf(&b, "curl -fsSL -o \"$tmp/%[1]s.zip\" \"%[2]s%[1]s.zip\"\n", font, config.NerdFontsReleaseBase)
					fmt.Fprintf(&b, "mkdir -p \"/usr/local/share/fonts/%s\"\n", font)
					fmt.Fprintf(&b, "unzip -o -q \"$tmp/%[1]s.zip\" -d \"/usr/local/share/fonts/%[1]s\"\n", font)
				}
				b.WriteString("fc-cache -f >/dev/null\n")
				b.WriteString("rm -rf \"$tmp\"\n")
				return e.Run.RootScript(b.String())
			},
		},
		{
			ID:       "icon-theme",
			Group:    GroupApps,
			Title:    "install the " + config.IconThemeName + " icon theme",
			Optional: true,
			Check: func(e *Env) bool {
				return exists(filepath.Join(home, ".local/share/icons", config.IconThemeName))
			},
			Run: func(e *Env) error {
				icons := filepath.Join(home, ".local/share/icons")
				tmp := filepath.Join(os.TempDir(), fmt.Sprintf("everforest-icons-%d", time.Now().Unix()))
				script := "set -e\n" +
					"mkdir -p " + shq(icons) + "\n" +
					"git clone --depth 1 " + shq(config.IconThemeRepo) + " " + shq(tmp) + "\n" +
					"cp -r " + shq(filepath.Join(tmp, config.IconThemeName)) + " " + shq(icons+"/") + "\n" +
					"rm -rf " + shq(tmp) + "\n"
				return e.Run.Script(script)
			},
		},

		// ----------------------------------------------------------- dev tooling
		{
			ID:       "bun",
			Group:    GroupDev,
			Title:    "install bun",
			Optional: true,
			Check: func(e *Env) bool {
				return e.Run.Has("bun") || exists(filepath.Join(home, ".bun/bin/bun"))
			},
			Run: func(e *Env) error {
				return e.Run.Script("curl -fsSL " + config.BunInstaller + " | bash")
			},
		},
		{
			ID:       "ttt",
			Group:    GroupDev,
			Title:    "install ttt (terminal editor)",
			Optional: true,
			Check: func(e *Env) bool {
				return e.Run.Has("ttt") || exists(filepath.Join(home, ".local/bin/ttt"))
			},
			Run: func(e *Env) error {
				return e.Run.Script("curl -sSfL " + config.TTTInstaller + " | sh")
			},
		},
		{
			ID:       "marksman",
			Group:    GroupDev,
			Title:    "install marksman (Markdown LSP)",
			Optional: true,
			Check: func(e *Env) bool {
				return exists(filepath.Join(home, ".local/bin/marksman"))
			},
			Run: func(e *Env) error {
				asset, ok := marksmanAsset()
				if !ok {
					return fmt.Errorf("no marksman build for %s", runtime.GOARCH)
				}
				dest := filepath.Join(home, ".local/bin/marksman")
				script := "set -e\n" +
					"mkdir -p " + shq(filepath.Dir(dest)) + "\n" +
					"curl -fsSL -o " + shq(dest) + " " + shq(config.MarksmanReleaseBase+asset) + "\n" +
					"chmod +x " + shq(dest) + "\n"
				return e.Run.Script(script)
			},
		},
		{
			ID:       "ttt-lsp",
			Group:    GroupDev,
			Title:    "install ttt language servers",
			Optional: true,
			Check: func(e *Env) bool {
				return e.Run.Has("vscode-html-language-server")
			},
			Run: func(e *Env) error {
				if !e.Run.Has("npm") {
					return fmt.Errorf("npm not found")
				}
				args := append([]string{"install", "-g", "--no-audit", "--no-fund"}, cfg.NpmGlobal...)
				return e.Run.Run("npm", args...)
			},
		},
		{
			ID:       "llmserve",
			Group:    GroupDev,
			Title:    "clone llmserve and run its setup",
			Optional: true,
			Check: func(e *Env) bool {
				return exists(filepath.Join(home, "projects/llmserve/.git"))
			},
			Run: func(e *Env) error {
				dir := filepath.Join(home, "projects/llmserve")
				script := "set -e\n" + "mkdir -p " + shq(filepath.Dir(dir)) + "\n"
				if exists(filepath.Join(dir, ".git")) {
					script += "git -C " + shq(dir) + " pull --ff-only\n"
				} else {
					script += "git clone " + shq(config.LLMServeRepo) + " " + shq(dir) + "\n"
				}
				script += "if [ -f " + shq(dir+"/setup.sh") + " ]; then bash " + shq(dir+"/setup.sh") + "; " +
					"elif [ -f " + shq(dir+"/install.sh") + " ]; then bash " + shq(dir+"/install.sh") + "; fi\n"
				return e.Run.Script(script)
			},
		},

		// -------------------------------------------------------------- dotfiles
		{
			ID:    "dotfiles-clone",
			Group: GroupDotfiles,
			Title: "clone " + cfg.DotfilesRepo,
			Check: func(e *Env) bool {
				return exists(filepath.Join(dotfiles, ".git"))
			},
			Run: func(e *Env) error {
				if exists(filepath.Join(dotfiles, ".git")) {
					return e.Run.Run("git", "-C", dotfiles, "pull", "--ff-only")
				}
				return e.Run.Run("git", "clone", cfg.DotfilesRepo, dotfiles)
			},
		},
		{
			ID:    "links",
			Group: GroupDotfiles,
			Title: fmt.Sprintf("symlink %d config paths into $HOME", len(cfg.Mappings)),
			Check: func(e *Env) bool {
				if !exists(filepath.Join(dotfiles, ".git")) {
					return false
				}
				return len(linkOptions(e).Verify(cfg.Mappings)) == 0
			},
			Run: func(e *Env) error {
				if !exists(dotfiles) {
					return fmt.Errorf("no repo at %s - clone it first", dotfiles)
				}
				opts := linkOptions(e)
				results, err := opts.All(cfg.Mappings)
				if err != nil {
					return err
				}
				linked := 0
				for _, res := range results {
					if res.Action != link.ActionSkip {
						linked++
					}
				}
				if linked == 0 && !e.Run.DryRun {
					return fmt.Errorf("nothing linked: %s has no matching files", dotfiles)
				}
				if e.Run.DryRun {
					return nil
				}
				failures := opts.Verify(cfg.Mappings)
				for _, f := range failures {
					e.Printf("MISS: %s is not linked into %s\n", f.Rel, dotfiles)
				}
				if len(failures) > 0 {
					return fmt.Errorf("%d paths are not linked", len(failures))
				}
				return nil
			},
		},
		{
			ID:       "opencode-deps",
			Group:    GroupDotfiles,
			Title:    "install opencode plugin dependencies",
			Optional: true,
			Check: func(e *Env) bool {
				return exists(filepath.Join(home, ".config/opencode/node_modules"))
			},
			Run: func(e *Env) error {
				dir := filepath.Join(home, ".config/opencode")
				if !exists(filepath.Join(dir, "package.json")) {
					return fmt.Errorf("no package.json in %s", dir)
				}
				if !e.Run.Has("npm") {
					return fmt.Errorf("npm not found")
				}
				return e.Run.Script("cd " + shq(dir) + " && npm install --no-audit --no-fund")
			},
		},

		// --------------------------------------------------------------- desktop
		{
			ID:       "theming",
			Group:    GroupDesktop,
			Title:    "apply GTK theme, icons and input settings",
			Optional: true,
			Check: func(e *Env) bool {
				if len(cfg.GSettings) == 0 {
					return true
				}
				g := cfg.GSettings[0]
				out, err := e.Run.Capture("gsettings", "get", g.Schema, g.Key)
				return err == nil && strings.TrimSpace(out) == g.Value
			},
			Run: func(e *Env) error {
				if !e.Run.Has("gsettings") {
					return fmt.Errorf("gsettings not found")
				}
				for _, g := range cfg.GSettings {
					if err := e.Run.Run("gsettings", "set", g.Schema, g.Key, g.Value); err != nil {
						return err
					}
				}
				return nil
			},
		},
		{
			ID:       "xfce-terminal",
			Group:    GroupDesktop,
			Title:    "make kitty the XFCE default terminal",
			Optional: true,
			Check: func(e *Env) bool {
				if !e.Run.Has("xfconf-query") {
					return true
				}
				out, err := e.Run.Capture("xfconf-query", "-c", "xfce4-session", "-p", "/general/TerminalEmulator")
				return err == nil && strings.Contains(out, "kitty")
			},
			Run: func(e *Env) error {
				if !e.Run.Has("xfconf-query") {
					return fmt.Errorf("xfconf-query not found")
				}
				pairs := [][2]string{
					{"/general/TerminalEmulator", "kitty"},
					{"/general/TerminalCommand", "kitty"},
				}
				for _, p := range pairs {
					_ = e.Run.Run("xfconf-query", "-c", "xfce4-session", "-p", p[0], "-s", p[1], "--create", "-t", "string")
				}
				_ = e.Run.Run("xfconf-query", "-c", "xfce4-terminal", "-p", "/misc/default-command",
					"-s", "kitty", "--create", "-t", "string")
				return nil
			},
		},
		{
			ID:        "keyboard",
			Group:     GroupDesktop,
			Title:     "set keyboard layout to " + cfg.KeymapX11 + " (" + cfg.KeymapTTY + ")",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				out, err := e.Run.Capture("localectl", "status")
				return err == nil && strings.Contains(out, cfg.KeymapTTY)
			},
			Run: func(e *Env) error {
				if err := e.Run.Root("localectl", "set-keymap", cfg.KeymapTTY); err != nil {
					return err
				}
				return e.Run.Root("localectl", "set-x11-keymap", cfg.KeymapX11)
			},
		},
		{
			ID:        "login-shell",
			Group:     GroupDesktop,
			Title:     "set login shell to " + cfg.LoginShell,
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				shell, err := exec.LookPath(cfg.LoginShell)
				if err != nil {
					return true // not installed: nothing to switch to
				}
				out, err := e.Run.Capture("getent", "passwd", user)
				if err != nil {
					return false
				}
				fields := strings.Split(strings.TrimSpace(out), ":")
				return len(fields) > 6 && fields[6] == shell
			},
			Run: func(e *Env) error {
				shell, err := exec.LookPath(cfg.LoginShell)
				if err != nil {
					return fmt.Errorf("%s is not installed", cfg.LoginShell)
				}
				return e.Run.Root("chsh", "-s", shell, user)
			},
		},
		{
			ID:        "display-manager",
			Group:     GroupDesktop,
			Title:     "ensure a display manager is enabled",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				return e.Run.OK("systemctl", "is-enabled", "display-manager")
			},
			Run: func(e *Env) error {
				if err := e.Run.Root("dnf", "install", "-y", "lightdm", "lightdm-gtk"); err != nil {
					return err
				}
				return e.Run.Root("systemctl", "enable", "lightdm")
			},
		},
		{
			ID:    "dirs",
			Group: GroupDesktop,
			Title: "create working directories",
			Check: func(e *Env) bool {
				return allExist(cfg.Dirs)
			},
			Run: func(e *Env) error {
				for _, dir := range cfg.Dirs {
					if e.Run.DryRun {
						e.Printf("+ mkdir -p %s\n", dir)
						continue
					}
					if err := os.MkdirAll(dir, 0o755); err != nil {
						return err
					}
				}
				return nil
			},
		},

		// -------------------------------------------------------------- services
		{
			ID:        "services-system",
			Group:     GroupServices,
			Title:     "enable system services",
			NeedsRoot: true,
			Check: func(e *Env) bool {
				for _, svc := range cfg.SystemServices {
					if !e.Run.OK("systemctl", "is-enabled", svc) {
						return false
					}
				}
				return true
			},
			Run: func(e *Env) error {
				for _, svc := range cfg.SystemServices {
					if !e.Run.OK("systemctl", "is-enabled", svc) {
						if err := e.Run.Root("systemctl", "enable", "--now", svc); err != nil {
							return err
						}
						continue
					}
					if !e.Run.OK("systemctl", "is-active", svc) {
						if err := e.Run.Root("systemctl", "start", svc); err != nil {
							return err
						}
					}
				}
				if e.Run.OK("systemctl", "is-enabled", "firewalld") {
					e.Printf("disabling firewalld (ufw is used instead)\n")
					_ = e.Run.Root("systemctl", "disable", "--now", "firewalld")
				}
				return nil
			},
		},
		{
			ID:       "services-user",
			Group:    GroupServices,
			Title:    "enable user services (syncthing)",
			Optional: true,
			Check: func(e *Env) bool {
				for _, svc := range cfg.UserServices {
					if !e.Run.OK("systemctl", "--user", "is-enabled", svc) {
						return false
					}
				}
				return true
			},
			Run: func(e *Env) error {
				for _, svc := range cfg.UserServices {
					if !e.Run.OK("systemctl", "--user", "is-enabled", svc) {
						if err := e.Run.Run("systemctl", "--user", "enable", "--now", svc); err != nil {
							return err
						}
					}
				}
				return nil
			},
		},
		{
			ID:        "linger",
			Group:     GroupServices,
			Title:     "enable lingering for " + user,
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				out, err := e.Run.Capture("loginctl", "show-user", user, "-p", "Linger")
				return err == nil && strings.Contains(out, "yes")
			},
			Run: func(e *Env) error {
				return e.Run.Root("loginctl", "enable-linger", user)
			},
		},
		{
			ID:        "ufw-tailscale",
			Group:     GroupServices,
			Title:     "allow traffic on tailscale0",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				out, err := e.Run.Capture("sudo", "-n", "ufw", "status")
				return err == nil && strings.Contains(out, "tailscale0")
			},
			Run: func(e *Env) error {
				return e.Run.Root("ufw", "allow", "in", "on", "tailscale0", "comment", "tailnet")
			},
		},

		// ----------------------------------------------------------- maintenance
		{
			ID:       "stale-paths",
			Group:    GroupMaintenance,
			Title:    "look for stale /home/... paths in configs",
			Optional: true,
			Run: func(e *Env) error {
				found := 0
				for _, dir := range cfg.StalePathDirs {
					_ = filepath.Walk(dir, func(p string, fi os.FileInfo, err error) error {
						if err != nil || fi.IsDir() {
							return nil
						}
						if !configFile(p) {
							return nil
						}
						data, err := os.ReadFile(p)
						if err != nil {
							return nil
						}
						if m := stalePathRE.Find(data); m != nil {
							e.Printf("stale path %s in %s\n", m, p)
							found++
						}
						return nil
					})
				}
				if found > 0 {
					return fmt.Errorf("%d files contain literal /home/... paths", found)
				}
				e.Printf("no stale paths found\n")
				return nil
			},
		},
		{
			ID:       "privatize",
			Group:    GroupMaintenance,
			Title:    "set the dotfiles repo to private",
			OptIn:    true,
			Optional: true,
			Check: func(e *Env) bool {
				out, err := e.Run.Capture("gh", "repo", "view", config.DotfilesSlug,
					"--json", "visibility", "-q", ".visibility")
				return err == nil && strings.TrimSpace(out) == "PRIVATE"
			},
			Run: func(e *Env) error {
				if !e.Run.Has("gh") {
					return fmt.Errorf("gh not installed")
				}
				return e.Run.Run("gh", "repo", "edit", config.DotfilesSlug,
					"--visibility", "private", "--accept-visibility-change-consequences")
			},
		},
	}

	if cfg.Variant == config.VariantLaptop {
		steps = append(steps, Step{
			ID:        "services-laptop",
			Group:     GroupServices,
			Title:     "enable thermald",
			NeedsRoot: true,
			Optional:  true,
			Check: func(e *Env) bool {
				for _, svc := range cfg.LaptopServices {
					if !e.Run.OK("systemctl", "is-enabled", svc) {
						return false
					}
				}
				return true
			},
			Run: func(e *Env) error {
				for _, svc := range cfg.LaptopServices {
					if err := e.Run.Root("systemctl", "enable", "--now", svc); err != nil {
						return err
					}
				}
				return nil
			},
		})
	}

	return steps
}

// LinkSteps returns just the symlink step, for `bootstrap link`.
func LinkSteps(cfg config.Config) []Step {
	all := All(cfg)
	for _, step := range all {
		if step.ID == "links" {
			return []Step{step}
		}
	}
	return nil
}

func linkOptions(e *Env) link.Options {
	return link.Options{
		DotfilesDir: e.Cfg.DotfilesDir,
		Home:        e.Cfg.Home,
		BackupDir:   e.Cfg.BackupDir,
		DryRun:      e.Run.DryRun,
		OnResult: func(res link.Result) {
			line := fmt.Sprintf("%-5s %s", string(res.Action)+":", res.Rel)
			switch res.Action {
			case link.ActionSkip:
				line += " (missing in repo)"
			case link.ActionBackup:
				line += " (was " + res.BackupTo + ")"
			}
			e.Printf("%s\n", line)
		},
	}
}

func exists(p string) bool {
	_, err := os.Lstat(p)
	return err == nil
}

func allExist(paths []string) bool {
	for _, p := range paths {
		if !exists(p) {
			return false
		}
	}
	return true
}

func configFile(p string) bool {
	switch filepath.Ext(p) {
	case ".conf", ".sh", ".ini", ".py", ".rasi", ".json", ".toml":
		return true
	}
	base := filepath.Base(p)
	return base == "config" || base == ".fehbg"
}

// shq quotes a string for a bash script.
func shq(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func currentUser() string {
	if u := os.Getenv("USER"); u != "" {
		return u
	}
	if u, err := user.Current(); err == nil {
		return u.Username
	}
	return ""
}

func marksmanAsset() (string, bool) {
	switch runtime.GOARCH {
	case "amd64":
		return "marksman-linux-x64", true
	case "arm64":
		return "marksman-linux-arm64", true
	}
	return "", false
}
