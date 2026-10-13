import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Right: tray (mirrors polybar internal/tray, 16px).
// StatusNotifier only - legacy XEmbed apps (some X11 trays) will NOT appear.
// Shown on primary screen only (shell.qml passes showTray).
Row {
  id: root
  spacing: 6

  Repeater {
    model: SystemTray.items

    IconImage {
      required property SystemTrayItem modelData
      implicitSize: 16
      width: 16
      height: 16
      source: {
        let icon = modelData.icon;
        if (!icon)
          return "";
        // icon may be "name" or full path; IconImage handles theme names via
        // image://icon/ provider? fallback: try theme lookup through QML image
        if (icon.startsWith("/") || icon.startsWith("file:"))
          return icon;
        return "image://icon/" + icon;
      }
      asynchronous: true

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
          if (mouse.button !== Qt.RightButton)
            parent.modelData.activate();
          else
            parent.modelData.secondaryActivate();
        }
      }
    }
  }
}
