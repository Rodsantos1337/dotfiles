// vim:syntax=qml
import QtQuick
import Quickshell
import Quickshell.I3._Ipc
import "./modules/" as Mod

/// Everforest topbar - TRI-ISLANDS: three floating pills on wallpaper.
/// Transparent backdrop, islands float with margin. Same palette.
/// Run: qs -c everforest &   Kill: pkill -x quickshell (polybar untouched)
ShellRoot {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors {
        top: false
        bottom: true
        left: true
        right: true
      }

      implicitHeight: Mod.Theme.barHeight + 8
      exclusiveZone: Mod.Theme.barHeight + 8
      color: "transparent"

      Item {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 4

        // LEFT ISLAND: workspaces
        Rectangle {
          id: leftIsland
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: workRow.implicitWidth + 28
          height: Mod.Theme.barHeight
          radius: Mod.Theme.radius
          color: Mod.Theme.bg
          border.width: 1
          border.color: Mod.Theme.border

          Mod.Workspaces {
            id: workRow
            anchors.centerIn: parent
            i3screen: modelData
          }
        }

        // CENTER ISLAND: clock
        Mod.Clock {
          anchors.centerIn: parent
        }

        // RIGHT ISLAND: sysstats
        Rectangle {
          id: rightIsland
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: rightRow.implicitWidth + 28
          height: Mod.Theme.barHeight
          radius: Mod.Theme.radius
          color: Mod.Theme.bg
          border.width: 1
          border.color: Mod.Theme.border

          Row {
            id: rightRow
            anchors.centerIn: parent
            spacing: 10

            Mod.CpuTemp {}

            Text {
              text: Mod.Theme.separator
              color: Mod.Theme.muted
              font.pixelSize: Mod.Theme.fontSize
            }

            Mod.Memory {}

            Text {
              text: Mod.Theme.separator
              color: Mod.Theme.muted
              font.pixelSize: Mod.Theme.fontSize
            }

            Mod.Disk {}

            Text {
              text: Mod.Theme.separator
              color: Mod.Theme.muted
              font.pixelSize: Mod.Theme.fontSize
            }

            Mod.Volume {}

            Text {
              text: Mod.Theme.separator
              color: Mod.Theme.muted
              font.pixelSize: Mod.Theme.fontSize
            }

            Mod.PowerProfile {}

            Mod.Battery {}

            // tray only on primary screen (mirrors launch.sh main vs main-notray)
            Mod.Tray {
              visible: (modelData != null && modelData.name !== undefined) ? true : true
            }
          }
        }
      }
    }
  }
}
