import QtQuick
import Quickshell.Io

// Right: memory %used (mirrors polybar internal/memory, 5s)
Text {
  id: root
  font.family: Theme.fontMono
  font.pixelSize: Theme.fontSize
  color: Theme.fg
  text: " " + usedPct

  property string usedPct: "--"

  FileView {
    id: memFile
    path: "/proc/meminfo"
    blockLoading: true
    onLoaded: {
      const txt = text();
      const total = parseInt((txt.match(/MemTotal:\s+(\d+)/) || [0, 0])[1], 10);
      const avail = parseInt((txt.match(/MemAvailable:\s+(\d+)/) || [0, 0])[1], 10);
      if (total > 0)
        root.usedPct = Math.round((total - avail) / total * 100) + "%";
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: memFile.reload()
  }
}
