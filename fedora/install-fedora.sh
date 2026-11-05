#!/usr/bin/env bash
#
# fedora/install-fedora.sh - wrapper for setup.sh (Fedora desktop)
# Kept for backward compatibility and documentation.

exec "$(dirname "${BASH_SOURCE[0]}")/../setup.sh" --desktop "$@"