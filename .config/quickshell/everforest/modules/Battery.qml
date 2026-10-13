import QtQuick
import Quickshell.Io

// Right: battery (mirrors polybar BAT0).
// Hidden when no battery exists (desktop has no /sys/class/power_supply/*).
Text {
  id: root
  font.family: Theme.fontMono
  font.pixelSize: Theme.fontSize
  color: charging ? Theme.green : Theme.fg
  visible: hasBattery
  text: " " + pct + "%" + (charging ? " +" : "")

  property bool hasBattery: false
  property string pct: "--"
  property bool charging: false

  FileView {
    id: capFile
    path: "/sys/class/power_supply/BAT0/capacity"
    blockLoading: true
    printErrors: false
    onLoaded: {
      const t = text().trim();
      if (t.length > 0) {
        root.hasBattery = true;
        root.pct = t;
      }
    }
    onLoadFailed: root.hasBattery = false
  }

  FileView {
    id: statusFile
    path: "/sys/class/power_supply/BAT0/status"
    blockLoading: true
    printErrors: false
    onLoaded: root.charging = text().trim() === "Charging"
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      capFile.reload();
      statusFile.reload();
    }
  }
}
