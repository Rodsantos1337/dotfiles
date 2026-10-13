import QtQuick
import Quickshell.Io

// Right: cpu-temp (mirrors polybar thermal-zone=3, warn 80C, 5s)
Text {
  id: root
  font.family: Theme.fontMono
  font.pixelSize: Theme.fontSize
  color: tempC >= 80 ? Theme.red : Theme.fg
  text: " " + (tempC >= 0 ? tempC + "°C" : "--")

  property int tempC: -1

  FileView {
    id: tempFile
    path: "/sys/class/thermal/thermal_zone3/temp"
    blockLoading: true
    onLoaded: {
      const t = parseInt(text().trim(), 10);
      if (!isNaN(t))
        root.tempC = Math.round(t / 1000);
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: tempFile.reload()
  }
}
