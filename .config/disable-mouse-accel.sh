#!/bin/bash
gsettings set org.gnome.desktop.peripherals.mouse accel-profile flat
gsettings set org.gnome.desktop.peripherals.touchpad accel-profile flat
for id in $(xinput list --id-only 2>/dev/null); do
  if xinput list-props "$id" 2>/dev/null | grep -q "libinput Accel Profile Enabled"; then
    xinput set-prop "$id" "libinput Accel Profile Enabled" 0, 1
  fi
done
