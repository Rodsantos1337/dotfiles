#!/usr/bin/env bash
# launch.sh - (re)start polybar on all monitors
# Called from i3 config. Per-monitor launch keeps tray on one bar only.

killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

if type xrandr >/dev/null 2>&1; then
  for m in $(xrandr --query | awk '/ connected/ {print $1}'); do
    MONITOR="$m" polybar --reload main &
  done
else
  polybar --reload main &
fi