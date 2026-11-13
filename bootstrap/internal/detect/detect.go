// Package detect answers the questions the tool asks before doing anything:
// which variant is this machine, and is it Fedora.
package detect

import (
	"os"
	"path/filepath"
	"strings"

	"dotfiles/bootstrap/internal/config"
)

// Variant guesses desktop or laptop as a preselected default. The guess is
// never trusted silently: callers show it and let the user change it.
func Variant() config.Variant {
	if hasBattery() {
		return config.VariantLaptop
	}
	switch chassisType() {
	case "8", "9", "10", "14", "30", "31", "32":
		return config.VariantLaptop
	}
	return config.VariantDesktop
}

func hasBattery() bool {
	bats, _ := filepath.Glob("/sys/class/power_supply/BAT*")
	return len(bats) > 0
}

func chassisType() string {
	data, err := os.ReadFile("/sys/class/dmi/id/chassis_type")
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// Fedora reports whether /etc/os-release says ID=fedora.
func Fedora() bool {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return false
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.EqualFold(strings.TrimSpace(line), "ID=fedora") {
			return true
		}
	}
	return false
}

// FedoraVersion returns the release number from VERSION_ID, e.g. "42".
func FedoraVersion() string {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "VERSION_ID=") {
			return strings.Trim(strings.TrimPrefix(line, "VERSION_ID="), `"`)
		}
	}
	return ""
}
