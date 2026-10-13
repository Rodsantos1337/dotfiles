import QtQuick
import Quickshell.Io

// Right: power profile (mirrors polybar pp-indicator + power-profiles rofi).
// click opens the existing rofi switcher script.
Text {
  id: root
  font.family: Theme.fontMono
  font.pixelSize: Theme.fontSize
  color: Theme.green
  text: " " + profile

  property string profile: "--"

  Process {
    id: ppProc
    command: ["powerprofilesctl", "get"]
    stdout: StdioCollector {}
    onExited: {
      const out = stdout.text.trim();
      if (out.length > 0)
        root.profile = out;
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: ppProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached([Quickshell.shellDir + "/../../i3/scripts/power-profiles"]);
  }
}
