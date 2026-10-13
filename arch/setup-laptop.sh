#!/usr/bin/env bash
#
# arch/setup-laptop.sh - wrapper for unified setup.sh (Arch laptop / Gigabyte G5 KF)
# Kept for backward compatibility and documentation.

exec "$(dirname "${BASH_SOURCE[0]}")/../setup.sh" --arch --laptop "$@"