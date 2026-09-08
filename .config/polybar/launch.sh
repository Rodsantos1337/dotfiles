#!/usr/bin/env bash
# launch.sh - (re)start polybar on all monitors
# Called from i3 config. Per-monitor launch keeps tray on one bar only.

killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

if type xrandr >/dev/null 2>&1; then
  # Tray bar pinned to DP-0 (user preference); everything else is tray-less.
  tray_monitor="DP-0"
  connected=$(xrandr --query | awk '/ connected/ {print $1}' | tr '\n' ' ')
  # fallback to primary/first if DP-0 is unplugged
  case " $connected " in
    *" $tray_monitor "*) ;;
    *) tray_monitor=$(xrandr --query | awk '/ connected primary/ {print $1}')
       [ -z "$tray_monitor" ] && tray_monitor=$(xrandr --query | awk '/ connected/ {print $1; exit}');;
  esac
  for m in $connected; do
    if [ "$m" = "$tray_monitor" ]; then
      MONITOR="$m" polybar --reload main &
    else
      MONITOR="$m" polybar --reload main-notray &
    fi
  done
else
  polybar --reload main &
fi