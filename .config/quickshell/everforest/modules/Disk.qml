import QtQuick
import Quickshell.Io

// Right: disk free on / (mirrors polybar internal/fs, 60s)
Text {
  id: root
  font.family: Theme.fontMono
  font.pixelSize: Theme.fontSize
  color: Theme.fg
  text: " " + freeText

  property string freeText: "--"

  Process {
    id: dfProc
    command: ["df", "-h", "/", "--output=avail"]
    stdout: StdioCollector {}
    onExited: {
      const lines = stdout.text.trim().split("\n");
      if (lines.length >= 2)
        root.freeText = lines[1].trim();
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: dfProc.running = true
  }
}
