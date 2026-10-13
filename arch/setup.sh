#!/usr/bin/env bash
#
# arch/setup.sh - wrapper for unified setup.sh (Arch desktop)
# Kept for backward compatibility and documentation.

exec "$(dirname "${BASH_SOURCE[0]}")/../setup.sh" --arch --desktop "$@"