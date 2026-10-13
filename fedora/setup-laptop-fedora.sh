#!/usr/bin/env bash
#
# fedora/setup-laptop-fedora.sh - wrapper for unified setup.sh (Fedora laptop)
# Kept for backward compatibility and documentation.

exec "$(dirname "${BASH_SOURCE[0]}")/../setup.sh" --fedora --laptop "$@"