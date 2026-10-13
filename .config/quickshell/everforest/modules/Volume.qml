import QtQuick
import Quickshell
import Quickshell.Io

// Right: volume via pactl (robust on PipeWire; Pipewire.volume binding
// fails on unbound default-sink nodes). Poll 2s like polybar.
// click=mute, wheel=+-5%, right-click=pavucontrol.
Text {
  id: root
  font.family: Theme.fontMono
  font.pixelSize: Theme.fontSize
  color: isMuted ? Theme.red : Theme.fg
  text: isMuted ? " muted" : " " + pct + "%"

  property bool isMuted: false
  property string pct: "--"

  Process {
    id: volProc
    command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | awk -F'/' '/Volume/{gsub(/[ %]/,\"\",$2); print $2}' && pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes && echo MUTED || echo UNMUTED"]
    stdout: StdioCollector {}
    onExited: {
      const lines = stdout.text.trim().split("\n");
      if (lines.length >= 1 && lines[0].length > 0)
        root.pct = lines[0].trim().replace("%", "");
      if (lines.length >= 2)
        root.isMuted = lines[1].trim() === "MUTED";
    }
  }

  Process {
    id: muteProc
    command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
    onExited: volProc.running = true
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!volProc.running)
      volProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        Quickshell.execDetached(["pavucontrol"]);
      else if (!muteProc.running)
        muteProc.running = true;
    }
    onWheel: wheel => {
      const dir = wheel.angleDelta.y > 0 ? "+5%" : "-5%";
      Quickshell.execDetached(["pactl", "set-sink-volume", "@DEFAULT_SINK@", dir]);
      volTimer.restart();
    }
  }

  Timer {
    id: volTimer
    interval: 300
    onTriggered: if (!volProc.running)
      volProc.running = true
  }
}
