// Package config holds the declarative provisioning data: repo URLs, package
// lists, symlink mappings and per-variant selections. It is the single source
// of truth the step list reads from.
package config

import (
	"os"
	"path/filepath"
	"time"
)

// Repository and asset locations. Edit here, not in the step list.
const (
	DotfilesRepo = "https://github.com/Rodsantos1337/dotfiles.git"
	DotfilesSlug = "Rodsantos1337/dotfiles"

	GitName  = "Rodsantos1337"
	GitEmail = "108137142+Rodsantos1337@users.noreply.github.com"

	TailscaleInstaller   = "https://tailscale.com/install.sh"
	OpencodeInstaller    = "https://opencode.ai/install"
	BunInstaller         = "https://bun.sh/install"
	TTTInstaller         = "https://raw.githubusercontent.com/eugenioenko/ttt/main/install.sh"
	MarksmanReleaseBase  = "https://github.com/artempyanykh/marksman/releases/latest/download/"
	NerdFontsReleaseBase = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/"
	IconThemeRepo        = "https://github.com/ItzSelenux/everforest-icon-theme"
	IconThemeName        = "Everforest-Dark"
	LLMServeRepo         = "https://github.com/Rodsantos1337/llmserve.git"

	RPMFusionFree    = "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-%s.noarch.rpm"
	RPMFusionNonFree = "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-%s.noarch.rpm"
	CoprRepo         = "sneexy/zen-browser"
	CoprMarker       = "sneexy"
)

// Variant is the machine type: "desktop" or "laptop".
type Variant string

const (
	VariantDesktop Variant = "desktop"
	VariantLaptop  Variant = "laptop"
)

// ParseVariant accepts "desktop" or "laptop" (case-insensitive) and returns
// ok=false for anything else.
func ParseVariant(s string) (Variant, bool) {
	switch Variant(s) {
	case VariantDesktop:
		return VariantDesktop, true
	case VariantLaptop:
		return VariantLaptop, true
	}
	return "", false
}

// Mapping describes one symlink: repo/rel/path -> $HOME/home/rel/path.
// If HomeRel is empty it defaults to RepoRel.
type Mapping struct {
	RepoRel string
	HomeRel string
}

// VariantMapping selects per-machine dotfiles variants:
// ~/.config/i3/local -> monitors-<variant> and
// ~/.config/flameshot/flameshot.ini -> flameshot-<variant>.ini.
type VariantMapping struct {
	I3Local      string // e.g. ".config/i3/monitors-desktop"
	FlameshotIni string // e.g. ".config/flameshot/flameshot-desktop.ini"
}

// GSetting is a single gsettings key/value.
type GSetting struct {
	Schema string
	Key    string
	Value  string
}

// Config holds all declarative provisioning data for one variant.
type Config struct {
	Variant        Variant
	Home           string
	BackupDir      string
	DotfilesRepo   string
	DotfilesDir    string
	DNFPkgs        []string
	ThirdPartyPkgs []string
	CoprRepos      []string
	Mappings       []Mapping
	VariantMapping VariantMapping
	SystemServices []string
	UserServices   []string
	LaptopServices []string
	GSettings      []GSetting
	KeymapTTY      string
	KeymapX11      string
	LoginShell     string
	NerdFonts      []string
	NpmGlobal      []string
	Dirs           []string
	StalePathDirs  []string
}

// BuildConfig returns the full provisioning config for a variant.
func BuildConfig(v Variant) Config {
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		home = os.Getenv("HOME")
	}

	cfg := Config{
		Variant:      v,
		Home:         home,
		BackupDir:    filepath.Join(home, ".dotfiles-backup-"+time.Now().Format("20060102-150405")),
		DotfilesRepo: DotfilesRepo,
		DotfilesDir:  filepath.Join(home, "dotfiles"),
		SystemServices: []string{
			"power-profiles-daemon",
			"ufw",
			"tailscaled",
		},
		UserServices: []string{
			"syncthing.service",
		},
		LaptopServices: []string{
			"thermald",
		},
		GSettings: []GSetting{
			{"org.gnome.desktop.interface", "icon-theme", "'Everforest-Dark'"},
			{"org.gnome.desktop.interface", "gtk-theme", "'Salvia-Dim'"},
			{"org.gnome.desktop.interface", "color-scheme", "'prefer-dark'"},
			{"org.gnome.desktop.interface", "cursor-size", "14"},
			{"org.gnome.desktop.peripherals.mouse", "accel-profile", "'flat'"},
			{"org.gnome.desktop.peripherals.touchpad", "accel-profile", "'flat'"},
		},
		KeymapTTY:  "pt-latin1",
		KeymapX11:  "pt",
		LoginShell: "zsh",
		NerdFonts:  []string{"GeistMono", "JetBrainsMono"},
		NpmGlobal:  []string{"vscode-langservers-extracted"},
		Dirs: []string{
			filepath.Join(home, "vault"),
			filepath.Join(home, "projects", "ACI", "screenshots"),
		},
		StalePathDirs: []string{
			filepath.Join(home, ".config", "i3"),
			filepath.Join(home, ".config", "polybar"),
			filepath.Join(home, ".config", "kitty"),
			filepath.Join(home, ".fehbg"),
		},
		DNFPkgs: []string{
			// build / clone toolchain
			"gcc", "gcc-c++", "make", "kernel-devel", "git", "curl", "wget",
			"fzf", "zoxide",
			// shell
			"zsh", "zsh-autosuggestions", "zsh-syntax-highlighting",
			// search / LSP
			"ripgrep", "fd-find", "clang-tools-extra",
			"python3-gobject", "pipx",
			// session / window manager
			"i3", "i3blocks", "i3lock", "xss-lock",
			"xorg-x11-server-Xorg", "xorg-x11-xinit", "xrandr", "xrdb", "xinput",
			// system UI
			"kitty", "dunst", "picom", "xsettingsd", "feh", "flameshot", "polybar", "rofi",
			"brightnessctl", "libnotify",
			"gtk-murrine-engine",
			"network-manager-applet", "power-profiles-daemon", "lm_sensors", "pavucontrol",
			"xdg-desktop-portal", "xdg-desktop-portal-gtk", "xdg-utils",
			// fonts (Nerd Fonts are installed separately via zip)
			"jetbrains-mono-fonts", "rsms-inter-fonts", "fontawesome4-fonts",
			// apps
			"Thunar", "nano", "qutebrowser", "steam",
			// spell check / gaming helpers
			"aspell", "aspell-en", "gamemode",
			// JS runtime
			"nodejs22", "nodejs22-npm",
			// tools
			"htop", "gh", "ufw", "unzip", "bluez", "bluez-tools", "smartmontools",
			"zram-generator", "efibootmgr", "syncthing", "pnpm",
			// repo tooling
			"dnf-plugins-core",
		},
		ThirdPartyPkgs: []string{
			"zen-browser",
		},
		CoprRepos: []string{
			CoprRepo,
		},
		Mappings: []Mapping{
			{RepoRel: ".xprofile"},
			{RepoRel: ".Xresources"},
			{RepoRel: ".bashrc"},
			{RepoRel: ".zshrc"},
			{RepoRel: ".fehbg"},
			{RepoRel: "wallpapers/bg.jpg", HomeRel: "Pictures/bg.jpg"},
			{RepoRel: "wallpapers/bg-old.jpg", HomeRel: "Pictures/bg-old.jpg"},
			{RepoRel: "wallpapers/new.jpg", HomeRel: "Pictures/new.jpg"},
			{RepoRel: "wallpapers/new-bg.jpg", HomeRel: "Pictures/new-bg.jpg"},
			{RepoRel: "wallpapers/bg-newer.jpg", HomeRel: "Pictures/bg-newer.jpg"},
			{RepoRel: ".config/i3/config"},
			{RepoRel: ".config/i3/scripts"},
			{RepoRel: ".config/kitty"},
			{RepoRel: ".config/dunst"},
			{RepoRel: ".config/fontconfig"},
			{RepoRel: ".config/gtk-3.0/settings.ini"},
			{RepoRel: ".config/gtk-4.0/settings.ini"},
			{RepoRel: ".config/opencode"},
			{RepoRel: ".config/picom"},
			{RepoRel: ".config/polybar"},
			{RepoRel: ".config/rofi"},
			{RepoRel: ".config/ttt"},
			{RepoRel: ".config/nvim"},
			{RepoRel: ".config/zed"},
			{RepoRel: ".config/alacritty"},
			{RepoRel: ".config/qutebrowser/config.py"},
			{RepoRel: ".config/xsettingsd"},
			{RepoRel: ".config/disable-mouse-accel.sh"},
			{RepoRel: ".config/mimeapps.list"},
			{RepoRel: ".config/user-dirs.dirs"},
			{RepoRel: ".config/user-dirs.locale"},
			{RepoRel: ".config/gamemode.ini"},
			{RepoRel: ".config/systemd"},
			{RepoRel: ".gitconfig"},
			{RepoRel: "bin/mm", HomeRel: ".local/bin/mm"},
			{RepoRel: "themes/Everforest-Green-Dark-Dim", HomeRel: ".local/share/themes/Everforest-Green-Dark-Dim"},
			{RepoRel: "themes/Salvia-Dim", HomeRel: ".local/share/themes/Salvia-Dim"},
			{RepoRel: "themes/Salvia", HomeRel: ".local/share/themes/Salvia"},
		},
	}

	// Per-machine i3 monitor + flameshot variants, expressed as ordinary
	// mappings so the link step needs exactly one code path.
	switch v {
	case VariantDesktop:
		cfg.VariantMapping = VariantMapping{
			I3Local:      ".config/i3/monitors-desktop",
			FlameshotIni: ".config/flameshot/flameshot-desktop.ini",
		}
	case VariantLaptop:
		cfg.VariantMapping = VariantMapping{
			I3Local:      ".config/i3/monitors-laptop",
			FlameshotIni: ".config/flameshot/flameshot-laptop.ini",
		}
	}

	cfg.Mappings = append(cfg.Mappings,
		Mapping{RepoRel: cfg.VariantMapping.I3Local, HomeRel: ".config/i3/local"},
		Mapping{RepoRel: cfg.VariantMapping.FlameshotIni, HomeRel: ".config/flameshot/flameshot.ini"},
	)

	// Laptop extras extend the base package list.
	if v == VariantLaptop {
		cfg.DNFPkgs = append(cfg.DNFPkgs, "thermald", "powertop", "acpi")
	}

	return cfg
}
